// 应用全局变量管理

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures, camel_case_types

import 'package:get/get.dart';
import 'package:linyaps_seal/utils/Backend_API/Linyaps_AppManager_API/linyaps_package_helper.dart';
import 'package:linyaps_seal/utils/config_classes/config_cur_app.dart';
import 'package:linyaps_seal/utils/config_classes/ext_defs/linyaps_extension.dart';
import 'package:linyaps_seal/utils/config_classes/linyaps_package_info.dart';

class GlobalAppState_AppConfig extends GetxController {  

  // 需要读取当前应用信息, 初始化为空信息
  Rx <LinyapsPackageInfo> curAppInfo = LinyapsPackageInfo(
    id: '',
    kind: 'app',
    base: '',
    name: '',
    version: '',
    description: '',
    arch:  '',
    Icon: '',
  ).obs;

  // 已存在的全局玲珑对应App配置, 并提供转换为JSON的Map<String, dynamic>形式
  // 未初始化, 需要每次切换页面执行下方updateAppConfig方法更新
  Rx <ConfigAll_App> curAppConf = ConfigAll_App(
    curAppInfo: LinyapsPackageInfo(
      kind: 'app', 
      id: '', 
      name: '', 
      base: '',
      version: '', 
      description: '', 
      arch: ''
    ),
  ).obs;

  // 读当前应用配置失败的原因; null 表示读到了(或这个应用还没写过配置)
  // 有它界面才说得出来: 否则配置读坏的表现是"这个应用没配过扩展和环境变量"
  Rxn<String> loadError = Rxn<String>();

  // 用于更新已存在的玲珑全局配置
  // 失败原因进 loadError 由界面显示, 不在这里咽掉
  Future <void> updateAppConfig (LinyapsPackageInfo newAppInfo) async {

    // 更新当前应用信息
    curAppInfo.value = newAppInfo;
    curAppConf.value.curAppInfo = curAppInfo.value;
    update();

    try {
      // 先更新扩展部分
      List <Extension>? cur_app_ext_conf = await LinyapsPackageHelper.get_config_extension_app(
        newAppInfo,
      );
      curAppConf.value
      .ext_defs = cur_app_ext_conf;

      // 再更新环境变量部分
      Map <String, String>? cur_app_env_conf = await LinyapsPackageHelper.get_env_config_app(
        newAppInfo,
      );
      curAppConf.value
      .env = cur_app_env_conf;

      // TODO: 去做新加别的配置功能

      loadError.value = null;
    } catch (e) {
      loadError.value = e.toString();
    }

    // 最后更新全局配置信息
    update();
    return;
  }

}
