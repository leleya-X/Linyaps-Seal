// 检查应用更新的类

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names

import 'package:dio/dio.dart';
import 'package:linyaps_seal/utils/Backend_API/version_compare/version_compare.dart';
import 'package:linyaps_seal/utils/app_version/app_version.dart';

class CheckAppUpdate {
    // 检查程序更新的函数
    // 返回 null 表示"这次没查成"(断网、GitHub 挂了、限流), 和 false(确实没有新版本)
    // 是两回事。原来一律返回 false, 等于把查不到说成"已经是最新的"
    static Future <bool?> isAppHaveUpate () async {
      // 版本号在 try 外面取: 取不到就该让这个错误直接冒出来,
      // 不能被下面那个"这次没查成"的 catch 吞掉 —— 否则会报成网络问题
      final cur_version = AppVersion.current;
      Dio dio = Dio();     // 创建Dio网络请求对象
      // 初始化检查更新的API链接
      String check_update_url = 'https://api.github.com/repos/leleya-X/Linyaps-Seal/releases';
      try {
        Response response = await dio.get(check_update_url);
        List <dynamic> version_list = response.data;
        // GitHub 返回的 API 请求中, 最新版本为第一位; 仓库还没有发布时列表为空
        if (version_list.isEmpty) return false;
        String newest_version = version_list[0]['tag_name'];
        return VersionCompare.isFirstGreaterThanSec(
          newest_version,
          cur_version,
        );
      } catch (e) {
        return null;
      }
    }
}
