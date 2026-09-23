// 页面中间件布局样式

// 忽略VSCode非必要报错
// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/state_manager.dart';
import 'package:linyaps_seal/pages/about_dialog/about_dialog.dart';
import 'package:linyaps_seal/pages/app_info_page/app_info.dart';
import 'package:linyaps_seal/utils/Global_Variables/installed_apps.dart';
import 'package:linyaps_seal/utils/check_update/check_update.dart';
import 'package:linyaps_seal/utils/check_update/dialog/Dialog_AppHaveUpdate.dart';
import 'package:linyaps_seal/utils/connection_check/check_connection_status.dart';
import 'package:linyaps_seal/utils/config_classes/linyaps_package_info.dart';
import 'package:linyaps_seal/utils/generic_widgets/linyaps_app_icon.dart';
import 'package:linyaps_seal/utils/page_utils/middle_page/app_bar.dart';
import 'package:yaru/icons.dart';
import 'package:yaru/widgets.dart';

class MainMiddlePage extends StatefulWidget {
  const MainMiddlePage({super.key});
  @override
  State<MainMiddlePage> createState() => _MainMiddlePageState();
}

class _MainMiddlePageState extends State<MainMiddlePage> {

  // 在当前页面检查应用是否有更新的方法
  // null 表示这次没查成(断网等), 与 false(确实没有新版本)不同
  Future <bool?> isAppHaveUpdate() async {
    return await CheckAppUpdate.isAppHaveUpate();
  }

  // 覆写父类构造函数
  @override
  void initState () {
    super.initState();
    // 拿到GetX全局对象
    GlobalAppState_InstalledApps globalinstalledAppList = Get.find<GlobalAppState_InstalledApps>();
    Future.microtask(() async {
      // 本地导出的图标先挂上: 这份不联网, 所以不等网络检查
      await globalinstalledAppList.updateAppsLocalIcon();
      // 检查网络连接状态
      // 若状态好则同时进行图标更新与应用更新检查
      bool is_connect_good = await CheckInternetConnectionStatus.staus_is_good();
      if (is_connect_good) {
        Future.microtask(() async {
          // 图标取不到不算大事: 列表照常可用, 界面上表现为一列通用图标 ——
          // 那本身是看得见的降级, 所以这里不打断页面。
          // 但不能一声不吭: 满屏通用图标的时候, 这条日志是唯一的线索
          try {
            await globalinstalledAppList.updateAppsIcon();
          } catch (e) {
            stderr.writeln('[图标] 从玲珑商店取图标失败: $e');
          }
        });
        Future.microtask(() async {
          // 只在确实查到有新版时才弹。查不成(null)不弹, 但也不等于"已是最新" ——
          // 只是这两种情况都不需要用户做什么, 所以都看不到东西
          final bool? hasUpdate = await isAppHaveUpdate();
          if (hasUpdate == true) {
            // 如果应用有更新就弹出对话框
            if (mounted) showDialog(
              context: context, 
              barrierDismissible: false,    // 禁止用户按空白部分关掉对话框
              builder: (BuildContext context) {
                return MyDialog_AppHaveUpdate();
              },
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 使用Yaru设计的左右分栏样式
    // 并使用两层GetBuilder监听
    return GetBuilder<GlobalAppState_InstalledApps>(    // 第一层监听已安装应用
      builder: (installedAppList) {
        return YaruMasterDetailPage(
          length: installedAppList.installedAppsList.length + 1,  // 列表项数量, 加1是算上第一项全部应用
          // 构建左侧的头部工具栏
          appBar: AppBar_MiddlePage(
            onPressed: () {
              showDialog(
                context: context, 
                builder:(context) => const MyAboutDialog(),
              );
            },
          ),
          // 设置左侧宽度
          paneLayoutDelegate: const YaruFixedPaneDelegate(
            paneSize: 300
          ),
          // 构建左侧列表项
          tileBuilder: (context, index, selected, availableWidth) {
            // 在第0项中加入全局应用菜单选项
            if (index == 0) {
              return SizedBox(
                height: 62,
                child: YaruMasterTile(
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // 左侧显示应用图标
                      Icon(
                        size: 50,
                        YaruIcons.app_grid,
                      ),
                      const SizedBox(width: 20,),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 180,
                            child: Text(
                              '全部应用程序',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: Text(
                              'Global Applications',
                              style: TextStyle(
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }
            LinyapsPackageInfo curApp = installedAppList.installedAppsList[index-1];
            return SizedBox(
              height: 62,
              child: YaruMasterTile(
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 左侧显示应用图标
                    LinyapsAppIcon(
                      key: ValueKey(curApp.name),
                      iconBytes: curApp.iconBytes,
                      iconIsSvg: curApp.iconIsSvg,
                      imageUrl: curApp.Icon ?? '',
                      size: 50,
                    ),
                    const SizedBox(width: 20,),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3,),
                        SizedBox(
                          width: 180,
                          child: Text(
                            curApp.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(height: 3,),
                        SizedBox(
                          width: 180,
                          child: Text(
                            curApp.version,
                            style: TextStyle(
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          // 构建右侧详情页  
          pageBuilder: (context, index) {
            // 如果是全部页面
            if (index == 0) {
              return AppInfoPage(
                curAppInfo: null
              );
            } else {
              return AppInfoPage(
                curAppInfo: installedAppList.installedAppsList[index-1],
              );
            }
          },
        );
      }
    );
  }
}
