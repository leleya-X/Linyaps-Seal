// 用于跟玲珑后端进行

// 忽略VSCode非必要报错
// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:io';
import 'package:env_variables/env_variables.dart';
import 'package:get/get.dart';
import 'package:linyaps_seal/utils/Backend_API/host_bridge.dart';
import 'package:linyaps_seal/utils/Global_Variables/cur_app_config_info.dart';
import 'package:linyaps_seal/utils/Global_Variables/global_config_info.dart';
import 'package:linyaps_seal/utils/config_classes/config_all_global.dart';
import 'package:linyaps_seal/utils/config_classes/config_cur_app.dart';

class LinyapsCliHelper {

  // 用于返回玲珑所有安装信息的方法
  // 取不到或解析不了都会抛, 不返回 null —— 这里没有"读不到"这个正常结果,
  // 只有读到和出错两种, 硬凑一个 null 出来只会让上层误以为"玲珑没装应用"
  static Future <Map<String, dynamic>> get_linyaps_all_local_info () async {
    // 一律由宿主侧的 linyapsd 把 states.json 原文经 D-Bus 传回来,
    // 不管应用本身跑在容器里还是宿主机上 (见 utils/Backend_API/host_bridge.dart)
    String get_states_content = await HostBridge.readStates();
    return jsonDecode(get_states_content) as Map<String, dynamic>;
  }

  // 用于返回玲珑用户全局配置信息的方法
  // 返回 null 只表示"用户还没写过全局配置"(文件不存在), 那是正常状态;
  // 文件在而内容坏了是另一回事, 直接抛, 不跟"没写过"混成同一个 null
  static Future <Map<String, dynamic>?> get_linyaps_global_config () async {
    // 先获取当前用户名
    String USER = EnvVariables.fromEnvironment('USER');
    File file = File('/home/$USER/.config/linglong/config.json');
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  // 用于返回玲珑用户对应应用配置信息的方法
  // 同 get_linyaps_global_config: null 仅表示这个应用还没写过配置
  static Future <Map<String, dynamic>?> get_linyaps_app_config (String appId) async {
    // 先获取当前用户名
    String USER = EnvVariables.fromEnvironment('USER');
    File file = File('/home/$USER/.config/linglong/apps/$appId/config.json');
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  // 用于将用户更改的内容写入JSON
  static Future <void> write_linyaps_global_config () async {
    // 获取全局变量状态
    GlobalAppState_Config curAppConfState = Get.find<GlobalAppState_Config>();
    ConfigAll_Global global_config_get = curAppConfState.global_config.value;
    // 转换字典为JSON格式的字符串, 以两个空格隔开
    String jsonString = const JsonEncoder.withIndent('  ').convert(global_config_get.toMap());
    // 获取当前用户名
    String USER = EnvVariables.fromEnvironment('USER');
    // 指定玲珑的states.json路径
    String linyaps_global_states_path = '/home/$USER/.config/linglong/config.json';
    File file = File(linyaps_global_states_path);
    // 确保目录存在
    await file.parent.create(recursive: true);
    // 将JSON文件写入路径
    await file.writeAsString(jsonString, mode: FileMode.write);
    return;
  }

  // 用于将用户更改的内容作为JSON写入至每个应用中
  static Future <void> write_linyaps_app_config () async {
    // 获取全局变量状态
    GlobalAppState_AppConfig curAppConfState = Get.find<GlobalAppState_AppConfig>();
    ConfigAll_App app_config_get = curAppConfState.curAppConf.value;
    // 获取当前应用ID
    String appId = app_config_get.curAppInfo.id;
    // 转换字典为JSON格式的字符串, 以两个空格隔开
    String jsonString = const JsonEncoder.withIndent('  ').convert(app_config_get.toMap());
    // 获取当前用户名
    String USER = EnvVariables.fromEnvironment('USER');
    // 指定玲珑的states.json路径
    String linyaps_global_states_path = '/home/$USER/.config/linglong/apps/$appId/config.json';
    File file = File(linyaps_global_states_path);
    // 确保目录存在
    await file.parent.create(recursive: true);
    // 将JSON文件写入路径
    await file.writeAsString(jsonString, mode: FileMode.write);
    return;
  }

}
