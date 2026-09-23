// 玲珑导出到宿主 /var/lib/linglong/entries/share 的桌面条目

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names

import 'dart:typed_data';

// 这是启动器看到的那份数据: desktop 文件和图标。
// 容器里没有这个目录(和 states.json 同理), 所以要经宿主侧的助手 linyapsd 取,
// 见 host_bridge.dart 的 readEntries()。

class LinyapsEntry {

  /// 应用 ID, 取自 desktop 里的 X-linglong。
  /// 文件名靠不住 —— drawio.desktop 对应的是 net.diagrams.drawio,
  /// qq.desktop 对应的是 linux.qq.com, 只有这个字段是玲珑装的时候写死的
  final String appId;

  /// desktop 文件原文
  final String desktop;

  /// 图标字节; null 表示这个应用没有主题图标, 不是读取失败
  final Uint8List? iconBytes;

  LinyapsEntry ({
    required this.appId,
    required this.desktop,
    this.iconBytes,
  });

  /// 图标是不是 SVG。
  /// 看字节开头而不是扩展名 —— 助手只回内容, 不带文件名
  bool get iconIsSvg {
    final bytes = iconBytes;
    if (bytes == null) return false;
    // 导出的矢量图都以 <?xml 或 <svg 开头; 前面可能有空行, 所以先去掉空白
    final head = String.fromCharCodes(bytes.take(8)).trimLeft();
    return head.startsWith('<');
  }

  /// 取 [Desktop Entry] 组下某个键的值, 比如 Name[zh_CN]。
  /// 只认那一个组: desktop 文件可以有多组, 同名键出现在别的组里不算数
  String? value (String key) {
    bool inEntry = false;
    for (final rawLine in desktop.split('\n')) {
      // 行尾可能带 CR —— 这些文件是各家包里的, 作者在哪个系统上编的都有
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('[')) {
        inEntry = line == '[Desktop Entry]';
        continue;
      }
      if (!inEntry || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq < 0) continue;
      if (line.substring(0, eq) == key) {
        return line.substring(eq + 1).trim();
      }
    }
    return null;
  }
}
