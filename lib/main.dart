// 主程序总线

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:get/get.dart';
import 'package:linyaps_seal/pages/middle_page.dart';
import 'package:linyaps_seal/pages/startup_error/startup_error.dart';
import 'package:linyaps_seal/utils/Global_Variables/cur_app_config_info.dart';
import 'package:linyaps_seal/utils/Global_Variables/global_config_info.dart';
import 'package:linyaps_seal/utils/Global_Variables/installed_apps.dart';
import 'package:linyaps_seal/utils/Global_Variables/repo_arch.dart';
import 'package:linyaps_seal/utils/app_version/app_version.dart';
import 'package:yaru/settings.dart';

void main() async {
  
  // 启动前先检查:
  // 1. 当前应用实例是否为单实例 (也就是只打开了一个app没打开第二个)
  // 2. 当前系统是否为Linux
  // 如果不是, 则退出程序
  bool isSingleInstance = await FlutterSingleInstance().isFirstInstance();
  if (!isSingleInstance || !Platform.isLinux) exit(0);

  // 实现监听窗口关闭行为, 实现快速且正常的关闭窗口按钮按下时的退出行为
  await FlutterWindowClose.setWindowShouldCloseHandler(() async {
    await ServicesBinding.instance.exitApplication(AppExitType.required);
    return false;
  });
  WidgetsFlutterBinding.ensureInitialized();   // 确保程序主窗口已加载

  // 初始化所有GetX管理的全局类实例
  // 创建GetX管理共享的ApplicationState实例
  Get.put(GlobalAppState_Arch());
  Get.put(GlobalAppState_InstalledApps());
  Get.put(GlobalAppState_Config());
  Get.put(GlobalAppState_AppConfig());

  // 初始化各实例
  GlobalAppState_Arch appGlobalInfo_arch = Get.find<GlobalAppState_Arch>();
  GlobalAppState_InstalledApps appGlobalInfo_installedApps = Get.find<GlobalAppState_InstalledApps>();
  GlobalAppState_Config appGlobalInfo_globalConf = Get.find<GlobalAppState_Config>();

  // 读出自己的版本号(来自 pubspec, 见 app_version.dart)。
  // 关于页和更新检查都用它, 全程只有这一份
  await AppVersion.load();

  // 启动时更新系统架构信息
  await appGlobalInfo_arch.getUnameArch();
  await appGlobalInfo_arch.getLinyapsStoreApiArch();

  // 更新已安装应用列表。
  // 数据在宿主侧, 由 linyapsd 经 D-Bus 提供 (见 host_bridge.dart),
  // 部署助手这件事就在这条链路里顺带做了 —— 不另设一步"预热":
  // 那一步的失败照样得有人接, 等于同样的错误要在两个地方各报一次
  await appGlobalInfo_installedApps.updateInstalledAppsList();

  // 再更新全局的应用配置
  await appGlobalInfo_globalConf.updateGlobalConfig();

  runApp(
    GetMaterialApp(
      home: const MyApp(),
    ),
  );
  
}

class MyApp extends StatefulWidget {

  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: YaruTheme(
        data: YaruThemeData(
          themeMode: ThemeMode.system,
        ),
        child: Obx(() {
          // 启动取数失败就把原因摆出来, 而不是照常进主界面 ——
          // 读不到数据时界面上的表现是一张空列表, 那和"确实没有数据"
          // 长得一模一样, 等于替出错这件事说了谎
          final loadError = AppVersion.loadError
              ?? Get.find<GlobalAppState_InstalledApps>().loadError.value
              ?? Get.find<GlobalAppState_Config>().loadError.value;
          if (loadError != null) {
            return StartupErrorView(
              message: loadError,
              onRetry: () async {
                await AppVersion.load();
                await Get.find<GlobalAppState_InstalledApps>().updateInstalledAppsList();
                await Get.find<GlobalAppState_Config>().updateGlobalConfig();
              },
            );
          }
          return const MainMiddlePage();
        }),
      ),
    );
  }
}
