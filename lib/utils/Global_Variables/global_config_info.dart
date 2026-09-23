// 应用全局变量管理

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures, camel_case_types

import 'package:get/get.dart';
import 'package:linyaps_seal/utils/Backend_API/Linyaps_AppManager_API/linyaps_package_helper.dart';
import 'package:linyaps_seal/utils/config_classes/config_all_global.dart';

class GlobalAppState_Config extends GetxController {

  // 已存在的全局玲珑配置, 并提供转换为JSON的Map<String, dynamic>的响应式
  Rx <ConfigAll_Global> global_config = ConfigAll_Global().obs;

  // 读全局配置失败的原因; null 表示读到了(或用户还没写过, 那也是正常状态)
  // 留在状态里是为了让界面说得出来: 否则配置读坏的表现会是"我的全局配置是空的"
  Rxn<String> loadError = Rxn<String>();

  // 用于更新已存在的玲珑全局配置
  // 失败原因进 loadError 由界面显示, 不在这里咽掉
  Future <void> updateGlobalConfig () async {
    try {
      // 先更新扩展部分
      var global_extension_config = await LinyapsPackageHelper.get_config_extension_global();
      // 这里直接赋, 不再"非空才覆盖": 拿到 null 说明用户没写过配置,
      // 那就该是空的; 保留上一次的值会让界面继续显示一份已经不存在的配置
      global_config.value.ext_defs = global_extension_config?.obs;

      // 再更新环境变量部分
      global_config.value.env = await LinyapsPackageHelper.get_env_config_global();

      // TODO: 去做新加别的扩展功能

      loadError.value = null;
    } catch (e) {
      loadError.value = e.toString();
    }
    update();
    return;
  }

}
