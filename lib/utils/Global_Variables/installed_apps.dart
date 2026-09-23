// 应用全局变量管理

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures, camel_case_types

import 'package:get/get.dart';
import 'package:linyaps_seal/utils/Backend_API/Linyaps_AppManager_API/linyaps_package_helper.dart';
import 'package:linyaps_seal/utils/Backend_API/Linyaps_Store_API/linyaps_store_api.dart';
import 'package:linyaps_seal/utils/config_classes/linyaps_package_info.dart';

class GlobalAppState_InstalledApps extends GetxController {

  // 私有已安装应用列表
  RxList installedAppsList = [].obs;

  // 最近一次取数失败的原因; null 表示这次取到了
  // 之所以留在这里而不是就地咽掉: 列表取不到和"一个应用都没装"在界面上
  // 是一模一样的空列表, 不把原因带到界面上, 用户就无从知道出了什么事
  Rxn<String> loadError = Rxn<String>();

  /*--         玲珑应用信息获取部分        --*/

  // 用于更新当前安装应用列表
  // 取数失败在这里被接住, 但不是兜底: 原因会存进 loadError 由界面显示出来
  Future <void> updateInstalledAppsList () async {
    try {
      installedAppsList.value = await LinyapsPackageHelper.get_installed_apps();
      loadError.value = null;
    } catch (e) {
      loadError.value = e.toString();
    }
    update();
    return;
  }

  // 用于更新已安装应用的图标
  Future <void> updateAppsIcon () async {
    installedAppsList.value = await LinyapsStoreApiService.updateAppIcon(installedAppsList.cast<LinyapsPackageInfo>());
    update();
    return;
  }

}
