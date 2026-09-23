// 用于对比"1.1.5.3"这样的版本号的类

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names

class VersionCompare {
  // 用于返回ver1是否大于ver2
  //
  // 逐段比较, 两边段数不同时缺的那几段按 0 算: "0.2" 和 "0.2.0" 是同一个版本,
  // "0.2.1" 大于 "0.2"。
  // 原来只循环 ver1 的段数, ver2 比它短就直接越界 —— 拿 "0.2.0" 和 "0.2" 比
  // 会抛 RangeError, 而不是给出答案
  static bool isFirstGreaterThanSec (String ver1, String ver2) {
    List <String> parted_ver1 = ver1.split('.');
    List <String> parted_ver2 = ver2.split('.');
    int len = parted_ver1.length > parted_ver2.length
        ? parted_ver1.length
        : parted_ver2.length;

    for (int i = 0; i < len; i++) {
      int parted1 = _partedAt(parted_ver1, i, ver1);
      int parted2 = _partedAt(parted_ver2, i, ver2);
      // 发现同级有大的直接返回判断
      if (parted1 > parted2) return true;
      if (parted2 > parted1) return false;
    }
    // 发现版本号一样也返回假
    return false;
  }

  // 取第 i 段; 超出长度按 0 算。
  // 解析不出数字就抛异常说明是哪个版本号的哪一段 ——
  // 原来的 tryParse(...)! 会在这里崩成一句 "Null check operator used on a null value",
  // 看不出是哪边、是哪一段的问题
  static int _partedAt (List <String> parted, int i, String origin) {
    if (i >= parted.length) return 0;
    int? part = int.tryParse(parted[i]);
    if (part == null) {
      throw FormatException(
        '版本号 "$origin" 的第 ${i + 1} 段 "${parted[i]}" 不是数字'
      );
    }
    return part;
  }
}
