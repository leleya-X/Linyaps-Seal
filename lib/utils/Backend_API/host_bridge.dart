// 玲珑容器穿透：向宿主机侧的助手 linyapsd 要只有宿主才拿得到的数据
//
// 为什么需要它：
//   Seal 的唯一数据源 /var/lib/linglong/states.json 在玲珑容器里根本不存在，
//   而且 /var/lib 是只读挂载，没法在容器内伪造这条路径。
//   所幸玲珑容器与宿主机共享 $HOME，也共享 session bus 的 socket，
//   于是可以往 ~/.local/share/dbus-1/services/ 放一份最普通的 D-Bus 服务文件，
//   让宿主的 bus 按需拉起小助手 linyapsd（见仓库根目录的 linyapsd/，Zig 写的），
//   由它在宿主命名空间里替我们读 states.json，原文经 D-Bus 返回值直传回来。
//   不落盘中转文件，也不写 systemd unit。
//
// 只有这一条链路。即便应用就跑在宿主机上、原路径本来就读得到，也照样走 D-Bus ——
// 留一条"这次能直读就直读"的旁路，等于让两种环境下的行为分叉：原生调得好好的，
// 进容器才暴露问题；而且两条路各有各的失败方式，排查时要先猜走的是哪条。
//
// 出错也不兜。这里读不到就抛出去，让界面直接说"读不到、原因是这个" ——
// 返回空串或 null 看着更省事，但调用方只能把它当成"读到了，是空的"，
// 于是"取数坏了"和"一个应用都没装"在界面上变得一模一样，谁也分不出来。

import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';

import 'package:linyaps_seal/utils/Backend_API/version_compare/version_compare.dart';
import 'package:linyaps_seal/utils/config_classes/linyaps_entry.dart';

class HostBridge {
  /// 宿主侧助手在 session bus 上的名字/路径/接口，须与 linyapsd/src/main.zig 一致
  static const String busName = 'io.github.leleya_x.Linyapsd';
  static const String objectPath = '/io/github/leleya_x/Linyapsd';
  static const String interface = 'io.github.leleya_x.Linyapsd.Manager';

  /// 宿主 $HOME，容器与它是同一个目录，所以照着写就等于写到宿主上。
  ///
  /// 取不到就说取不到，不兜成空串 —— 空串会拼出 `/.local/share/linyapsd`
  /// 这种看着像路径、实际往根目录去的东西，而且从报错里也看不出是 HOME 没读到。
  static String get _home {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('环境里没有 HOME，定位不到宿主侧的落点');
    }
    return home;
  }

  /// 助手的宿主落点。
  ///
  /// 路径里不带本应用的 ID：linyapsd 是通用的宿主侧扩展，不算本应用的私有部件，
  /// 别的玲珑应用也可以往这儿装、也都能用同一份。落点固定，谁装的都一样。
  /// $HOME 容器与宿主共享，所以容器内写这里等于写到宿主。
  static String get _shareDir => '$_home/.local/share/linyapsd';
  static String get _daemonPath => '$_shareDir/linyapsd';

  static String get _serviceDir => '$_home/.local/share/dbus-1/services';
  static String get _servicePath => '$_serviceDir/$busName.service';

  static DBusClient? _client;
  static bool _ready = false;

  /// 读取宿主机的 states.json 原文。
  ///
  /// 路径写死在 linyapsd 里，这边不重复一份 —— 两边各写一份迟早对不上，
  /// 而对不上的表现是"文件明明在却读不到"，最难查。
  ///
  /// 读不到就抛，不返回空串或 null：拿不到就是拿不到，得让调用方知道，
  /// 否则它只能自己编一个"读到了但是空的"来解释 —— 那在界面上和"一个应用都没装"
  /// 长得一模一样，等于把"取数坏了"伪装成"没有数据"。
  static Future<String> readStates() async {
    await _ensureReady();
    final reply = await _dbus().callMethod(
      destination: busName,
      path: DBusObjectPath(objectPath),
      interface: interface,
      name: 'ReadStates',
      replySignature: DBusSignature('s'),
    );
    return reply.returnValues[0].asString();
  }

  /// 读宿主 /var/lib/linglong/entries/share 下的桌面条目与图标。
  ///
  /// 这是启动器看到的那份数据。容器里没有这个目录，所以同样要经助手取；
  /// 相比去问玲珑商店，它有两个好处：离线也在，以及商店不认的包
  /// （本地构建、侧载的）同样有图标。
  ///
  /// 读不到就抛，和 readStates 一样不兜 —— 界面那边按"图标是装饰"处理，
  /// 但原因要带出来，不能变成一片没人知道为什么的通用图标。
  static Future<List<LinyapsEntry>> readEntries() async {
    await _ensureReady();
    final reply = await _dbus().callMethod(
      destination: busName,
      path: DBusObjectPath(objectPath),
      interface: interface,
      name: 'ReadEntries',
      replySignature: DBusSignature('a(ssay)'),
    );

    final entries = <LinyapsEntry>[];
    for (final item in reply.returnValues[0].asArray()) {
      final fields = item.asStruct();
      final bytes = Uint8List.fromList(fields[2].asByteArray().toList());
      entries.add(LinyapsEntry(
        appId: fields[0].asString(),
        desktop: fields[1].asString(),
        // 空数组和"没有图标"是同一件事: 助手找不到图标时回的就是空数组，
        // 界面拿到 null 就走通用图标那条路
        iconBytes: bytes.isEmpty ? null : bytes,
      ));
    }
    return entries;
  }

  static DBusClient _dbus() => _client ??= DBusClient.session();

  /// 部署助手并确认 bus 认得它，只做一次。成败都记在 _ready 里：
  /// 成了不必再来一遍，败了也不必每次取数都白等一趟部署流程。
  /// 但失败不会就此咽掉，异常照抛 —— 在哪儿抛出去由调用方决定，
  /// 这里不替它做主说"算了"。
  static Future<void> _ensureReady() async {
    if (_ready) return;
    await _deploy();
    _ready = true;
  }

  static Future<void> _deploy() async {
    // 助手由 linglong.yaml 和主程序装进同一个目录，只认这一处。
    // 从前这里是个候选列表，第一个找不到就去 /usr/bin 碰碰运气；删掉的原因是
    // 万一真用上了第二处，跑起来的就是和别人打包时想的不是同一份，
    // 而这种事不出问题看不出来 —— 正是这个项目到处要躲的那种"分叉"。
    final source = '${File(Platform.resolvedExecutable).parent.path}/linyapsd';
    if (!await File(source).exists()) {
      throw StateError('应用包里没有 $source，打包时漏掉了 linyapsd');
    }

    // 1. 把助手放到宿主 $HOME 下
    if (await _shouldInstall(source)) {
      await _installDaemon(source);
    }

    // 2. 放 D-Bus 服务文件。内容一致就不动 —— bus 每次收到文件变更都会重扫全部服务
    final entry = '[D-BUS Service]\n'
        'Name=$busName\n'
        'Exec=$_daemonPath\n';
    await Directory(_serviceDir).create(recursive: true);
    final serviceFile = File(_servicePath);
    if (!await serviceFile.exists() ||
        await serviceFile.readAsString() != entry) {
      await serviceFile.writeAsString(entry);
    }

    // 3. 让 bus 认得它
    await _startService();
  }

  /// 请 bus 拉起助手。
  ///
  /// 全新系统上 ~/.local/share/dbus-1/services/ 是刚建出来的：dbus-broker 只在
  /// 自己启动时扫描服务目录并挂 inotify，晚建的目录它没监听，因此认不出刚放进去的
  /// 服务文件（现象是 The name is not activatable）。
  /// 所以先调 ReloadConfig 让它重扫一遍 —— 它和 SIGHUP 走同一个内部函数，
  /// 只重读配置，不重启 bus、不断开已有连接。
  ///
  /// 这一步是无条件的：一开始写成"先 StartServiceByName，报 ServiceUnknown 再
  /// Reload 重试"，那样每次部署就分成了两条路 —— 目录早就在的机器走一条，新装的
  /// 走另一条，从外面看毫无区别，出问题时还得先判断这回走的是哪条。
  static Future<void> _startService() async {
    final client = _dbus();
    await client.callMethod(
      destination: 'org.freedesktop.DBus',
      path: DBusObjectPath('/org/freedesktop/DBus'),
      interface: 'org.freedesktop.DBus',
      name: 'ReloadConfig',
    );
    await client.callMethod(
      destination: 'org.freedesktop.DBus',
      path: DBusObjectPath('/org/freedesktop/DBus'),
      interface: 'org.freedesktop.DBus',
      name: 'StartServiceByName',
      values: [DBusString(busName), const DBusUint32(0)],
    );
  }

  /// 落点上要不要换成包里带的这一份。
  ///
  /// 落点是全宿主共用的，谁装的都一样，所以不能无脑覆盖别人放的那份 ——
  /// 比版本号，只有自己这份更新才装。
  static Future<bool> _shouldInstall(String source) async {
    if (!await File(_daemonPath).exists()) return true;

    final mine = await _readVersion(source);
    if (mine == null) {
      // 连包里自带这份都问不出 --version，那是打包出了问题。
      // 拿它去覆盖落点只会把本来是好的那份也弄坏，所以直接说，不换。
      throw StateError('包内的 $source 执行 --version 得不到合法版本号，产物有问题');
    }

    final theirs = await _readVersion(_daemonPath);
    if (theirs == null) {
      // 落点上那份跑不起来，不是个能用的 linyapsd，换掉
      return true;
    }

    return VersionCompare.isFirstGreaterThanSec(mine, theirs);
  }

  /// 读出某个 linyapsd 二进制的版本号；不是能用的 linyapsd 就返回 null。
  ///
  /// 版本号一律从二进制本身问，不在代码里另写一份 —— 两边各写一份迟早对不上，
  /// 而且对不上的时候是"以为装好了其实没装"，最难查。
  static Future<String?> _readVersion(String path) async {
    final ProcessResult r;
    try {
      r = await Process.run(path, ['--version']);
    } on ProcessException {
      return null;
    }
    if (r.exitCode != 0) return null;
    final v = (r.stdout as String).trim();
    // 版本比较那套按 "1.2.3" 拆段，喂它别的东西会直接抛越界。
    // 格式不对就当作"这不是我们的 linyapsd"，而不是硬塞进去
    return _versionPattern.hasMatch(v) ? v : null;
  }

  static final RegExp _versionPattern = RegExp(r'^\d+(\.\d+)*$');

  /// 装上包里带的这份，然后让可能还在跑的旧实例让位。
  static Future<void> _installDaemon(String source) async {
    // 文件换了不等于新版本生效：旧进程还占着 bus name 的话，调用照旧由它响应，
    // 从外面完全看不出已经换了。先请它退场，下次调用 bus 拉起的才是新的。
    await _retireRunningInstance();

    await Directory(_shareDir).create(recursive: true);
    await File(source).copy(_daemonPath);
    await Process.run('chmod', ['755', _daemonPath]);
  }

  /// 请正在跑的实例退出（linyapsd 的 Quit 方法）。没人在跑就什么都不做。
  static Future<void> _retireRunningInstance() async {
    final client = _dbus();
    if (!await _nameHasOwner(client)) return;

    try {
      await client.callMethod(
        destination: busName,
        path: DBusObjectPath(objectPath),
        interface: interface,
        name: 'Quit',
        replySignature: DBusSignature('s'),
      );
    } on DBusErrorException catch (e) {
      // 跑着的是还不认识 Quit 的老版本（Quit 是这一版才加的）。它能正常服务，
      // 所以不算坏事，但文件换掉之后它会继续用旧代码响应 —— 这事说出来，
      // 否则表现就是"明明更新了却还是老样子"
      stderr.writeln('[HostBridge] 落点上的 linyapsd 不支持 Quit，无法让它让位；'
          '新版本要等它自行退出后才会生效 (${e.errorName})');
    }
  }

  static Future<bool> _nameHasOwner(DBusClient client) async {
    final reply = await client.callMethod(
      destination: 'org.freedesktop.DBus',
      path: DBusObjectPath('/org/freedesktop/DBus'),
      interface: 'org.freedesktop.DBus',
      name: 'NameHasOwner',
      values: [DBusString(busName)],
      replySignature: DBusSignature('b'),
    );
    return reply.returnValues[0].asBoolean();
  }
}
