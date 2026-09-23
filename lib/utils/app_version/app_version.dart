// 应用自身的版本号

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:io';

/// 版本号的唯一真源是 pubspec.yaml 的 `version:`。
/// Flutter 打包时会把它写进 bundle 里的 data/flutter_assets/version.json，
/// 这里就读那一份，不在 Dart 里另抄一个常量。
///
/// 抄一份的代价不是多写一行，而是两处迟早对不上：对不上时关于页显示的是个
/// 过期版本号，更新检查拿它去比也永远比错，而这两处都不会报错，没人看得出来。
class AppVersion {

  static String? _value;
  static String? _loadError;

  /// 最近一次读取失败的原因；null 表示读到了。
  ///
  /// 和 GlobalAppState_InstalledApps.loadError 一样，读不到就把原因带出来
  /// 交给界面显示，不在这儿兜一个看着像模像样的假版本号 ——
  /// 版本号是要参与比较的，一个假值比一个明确的错误危险得多。
  static String? get loadError => _loadError;

  /// 启动时读一次。
  static Future <void> load () async {
    try {
      // Flutter Linux bundle 的布局：可执行文件与 data/ 同级
      final exe_dir = File(Platform.resolvedExecutable).parent.path;
      final path = '$exe_dir/data/flutter_assets/version.json';

      final file = File(path);
      if (!await file.exists()) {
        throw StateError('找不到 $path（打包时漏了 Flutter 的 version.json？）');
      }

      final data = jsonDecode(await file.readAsString());
      final version = (data as Map)['version'];
      if (version is! String || version.isEmpty) {
        throw StateError('$path 里没有可用的 version 字段：$data');
      }

      _value = version;
      _loadError = null;
    } catch (e) {
      _loadError = e.toString();
    }
    return;
  }

  /// 当前版本号。启动时没读到就直接抛出原因，不返回占位值。
  static String get current {
    final value = _value;
    if (value == null) {
      throw StateError(
        '版本号不可用：${_loadError ?? 'AppVersion.load() 没被调用过'}'
      );
    }
    return value;
  }

}
