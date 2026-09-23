// 应用全局变量管理

// 关闭VSCode非必要报错
// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures, camel_case_types

import 'dart:io';

import 'package:get/get.dart';
import 'package:linyaps_seal/utils/Backend_API/Linyaps_AppManager_API/linyaps_package_helper.dart';
import 'package:linyaps_seal/utils/Backend_API/Linyaps_Store_API/linyaps_store_api.dart';
import 'package:linyaps_seal/utils/Backend_API/host_bridge.dart';
import 'package:linyaps_seal/utils/config_classes/linyaps_entry.dart';
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

  // 用宿主导出的桌面条目给应用挂上图标
  //
  // 数据源是 /var/lib/linglong/entries/share, 也就是启动器看到的那份, 离线也有,
  // 而且商店不认的包同样有图标。取不到不算大事 —— 界面会退回通用图标,
  // 那是看得见的降级, 所以不打断页面; 但也不能一声不吭,
  // 满屏通用图标的时候, 这条路是唯一能说明为什么的线索
  Future <void> updateAppsLocalIcon () async {
    List <LinyapsEntry> entries;
    try {
      entries = await HostBridge.readEntries();
    } catch (e) {
      stderr.writeln('[图标] 取宿主导出的桌面条目失败: $e');
      return;
    }

    // 按 appId 建索引。助手那边认的是 desktop 里的 X-linglong,
    // 与列表里的 id 是同一个东西
    Map <String, LinyapsEntry> byAppId = {};
    for (LinyapsEntry e in entries) {
      byAppId[e.appId] = e;
    }

    for (dynamic item in installedAppsList) {
      LinyapsPackageInfo app = item;
      LinyapsEntry? entry = byAppId[app.id];
      if (entry == null) continue;   // 没有导出条目的应用保持原样, 不编一个
      app.iconBytes = entry.iconBytes;
      app.iconIsSvg = entry.iconIsSvg;
    }
    update();
    return;
  }

  // 本地没有图标的那些, 再去问玲珑商店要图标地址
  Future <void> updateAppsIcon () async {
    // 本地已经在手里的, 不再去商店取一遍: 同一个图标两条来源迟早会分叉
    List <LinyapsPackageInfo> needIcon = installedAppsList
        .cast <LinyapsPackageInfo> ()
        .where((app) => app.iconBytes == null)
        .toList();
    if (needIcon.isEmpty) return;

    Map <String, String> urls = await LinyapsStoreApiService.fetchAppIconUrls(needIcon);
    for (dynamic item in installedAppsList) {
      LinyapsPackageInfo app = item;
      if (app.iconBytes != null) continue;
      String? url = urls[app.id];
      if (url == null) continue;
      app.Icon = url;
    }
    update();
    return;
  }

}
