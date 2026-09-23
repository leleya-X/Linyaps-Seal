// 与玲珑应用商店后端API对接的中间件

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names, library_prefixes

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/instance_manager.dart';
import 'package:linyaps_seal/utils/Global_Variables/repo_arch.dart';
import 'package:linyaps_seal/utils/config_classes/linyaps_package_info.dart';

class LinyapsStoreApiService {
  // 初始化指定API总线链接地址
  static String serverHost_Store = "https://storeapi.linyaps.org.cn";
  static String serverHost_Repo = "https://mirror-repo-linglong.deepin.com";
  static String serverHost_RepoExtra = "https://cdn-linglong.odata.cc/icon/main";

  // 拿到GetX的全局应用信息
  static GlobalAppState_Arch gAppState_Arch = Get.find<GlobalAppState_Arch>();

  // 进行系统架构更新
  static String os_arch = gAppState_Arch.os_arch.value;
  static String repo_arch = gAppState_Arch.repo_arch.value;

  // 从商店取已安装应用的图标地址, 回 appId -> 图标链接。
  //
  // 只回这一张表, 不碰传进来的列表: 从前这里是"拿商店返回的条目重建一份列表",
  // 而商店只认识它上架过的包, 于是本地构建、侧载的包在图标更新之后
  // 整个从列表里消失了 —— 取个图标顺手把数据丢了。
  static Future <Map <String, String>> fetchAppIconUrls (List<LinyapsPackageInfo> installed_apps) async {
    // 指定具体响应API地址
    String serverUrl = '$serverHost_Store/visit/getAppDetails';

    // 初始化待提交应用
    List <Map<String, String>> upload_installed_apps = [];
    for (LinyapsPackageInfo i in installed_apps) {
      upload_installed_apps.add({
        'appId': i.id,
        'channel': 'main',
        'module': 'binary',
        'arch': repo_arch
      });
    }
    // 创建Dio请求对象
    Dio dio = Dio ();
    // 发送并获取返回信息
    Response response = await dio.post(
      serverUrl,
      data: jsonEncode(upload_installed_apps),
    );
    dio.close();

    List <dynamic> app_info_get = response.data['data'];
    Map <String, String> returnItems = {};

    for (dynamic i in app_info_get) {
      // 商店偶尔会返回本地列表里没有的 appId(本地刚好变过), 那种没有条目可挂, 跳过。
      // 凭空造一条出来比缺一条更难查。
      // 商店没给图标的条目同样跳过: 挂个空串上去, 界面只会拿到一个取不出图的地址
      final String? appId = i['appId'];
      final String? icon = i['icon'];
      if (appId == null || icon == null || icon.isEmpty) continue;
      if (!installed_apps.any((app) => app.id == appId)) continue;
      returnItems[appId] = icon;
    }

    return returnItems;
  }
}
