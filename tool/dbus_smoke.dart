// 命令行脚本，结果就是往 stdout 打，不需要换成日志框架
// ignore_for_file: avoid_print

// linyapsd 的端到端冒烟测试。
//
// 故意不预先启动 linyapsd：让它由 session bus 按需激活，
// 这样一次跑通既验证了各个方法，也验证了激活链路本身
// （激活这条路上出过问题，手工启动正常、bus 拉起就没响应）。
//
//   dart run tool/dbus_smoke.dart
//
// 前提：~/.local/share/dbus-1/services/ 下已装好服务文件，见 linyapsd/README.md。
import 'package:dbus/dbus.dart';
import 'package:linyaps_seal/utils/Backend_API/host_bridge.dart';

// 名字/路径/接口直接用应用自己那份常量，不在这里另抄一遍：
// 两边各写一份的话，哪天改了一处、这里照样通过，测的就成了别的东西。
const busName = HostBridge.busName;
const objectPath = HostBridge.objectPath;
const iface = HostBridge.interface;

Future<void> main() async {
  final client = DBusClient.session();
  final object = DBusRemoteObject(client,
      name: busName, path: DBusObjectPath(objectPath));

  final pong = await object.callMethod(
      iface, 'Ping', const [], replySignature: DBusSignature('s'));
  print('Ping      -> ${pong.returnValues[0].asString()}');

  final ver = await object.callMethod(
      iface, 'Version', const [], replySignature: DBusSignature('s'));
  print('Version   -> ${ver.returnValues[0].asString()}');

  final states = await object.callMethod(
      iface, 'ReadStates', const [], replySignature: DBusSignature('s'));
  final text = states.returnValues[0].asString();
  print('ReadStates-> ${text.length} 字符, 开头: ${text.substring(0, 40)}');

  // 桌面条目: 数一下有多少条, 以及有多少条真带着图标字节。
  // 只看条数不够 —— 图标读不到时助手照样会回条目(字节数组为空),
  // 只报条数的话, "有 desktop 没图标"这种半截结果看起来和全好一样
  final entries = await object.callMethod(
      iface, 'ReadEntries', const [], replySignature: DBusSignature('a(ssay)'));
  final list = entries.returnValues[0].asArray();
  int withIcon = 0;
  for (final item in list) {
    if (item.asStruct()[2].asByteArray().isNotEmpty) withIcon++;
  }
  print('ReadEntries -> ${list.length} 条桌面条目, 其中 $withIcon 条带图标');

  // LaunchApp 恒回空串，从返回值上分不出成败，所以这里能验证的只有"调用链通"。
  // 挑一个肯定不存在的应用 ID：真调一个已装的会把应用窗口弹出来，冒烟测试不该干那种事。
  // ll-cli 那句 "package not found" 落在 linyapsd 的 stderr 上（也就是 journal），
  // 不从这里过。
  final launched = await object.callMethod(iface, 'LaunchApp',
      [const DBusString('com.example.nonexistent')],
      replySignature: DBusSignature('s'));
  print('LaunchApp -> 返回 "${launched.returnValues[0].asString()}"'
      '（恒为空串，看不出成败，属正常）');

  // 空应用 ID 是实打实能判的：助手该拒绝，而不是照样 fork 一个 ll-cli 出来
  try {
    await object.callMethod(iface, 'LaunchApp', [const DBusString('')],
        replySignature: DBusSignature('s'));
    print('LaunchApp 空应用 ID -> 竟然通过了！');
  } on DBusErrorException catch (e) {
    print('LaunchApp 空应用 ID -> 已拒绝 (${e.errorName}: ${e.message})');
  }

  await client.close();
}
