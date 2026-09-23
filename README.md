# LinyapsSeal

管理如意玲珑（Linyaps）应用权限的 Linux 桌面应用。

列出系统上已安装的玲珑应用，查看并编辑每个应用的权限、环境变量与扩展配置，以及玲珑的全局配置。
纯 Linux 桌面端（Flutter + GTK），玲珑包 ID `io.github.leleya-x.linyaps-seal`。

## 功能

- **应用列表**：读取 `/var/lib/linglong/states.json`，跳过 `base` / `runtime` / `extension` 类型的 layer，
  其余作为应用条目列出；图标从玲珑商店 API（`storeapi.linyaps.org.cn`）按架构拉取并缓存。
- **应用配置**：按应用查看与编辑权限、环境变量、扩展，写回 `~/.config/linglong/apps/<appid>/config.json`。
- **全局配置**：查看与编辑玲珑全局环境变量等，写回 `~/.config/linglong/config.json`。
- **更新检查**：启动时比对 [GitHub Releases](https://github.com/leleya-X/Linyaps-Seal/releases)，
  有新版才弹提示；查不到（断网、限流、还没有 release）就不打扰用户 —— 这种情况的表现是
  "永远没反应"，而不是"已是最新"。
- **单实例运行**：重复启动时直接退出已有窗口。

界面用 [Yaru](https://github.com/ubuntu/yaru.dart) 主题，状态管理用 GetX。

## 开发环境

- Flutter 3.44.6 / Dart 3.12.2
- 仅 Linux 平台（仓库不含 Android / iOS / macOS / Windows / Web 目录）
- 运行主机需已安装玲珑（`ll-cli`）

## 构建运行

```bash
flutter pub get
flutter run -d linux                 # 开发调试
flutter build linux --release        # 产出 build/linux/x64/release/bundle/
```

## 打包成玲珑应用

打包用 [ll-killer](https://github.com/System233/ll-killer-go/releases)，一个可下载的二进制，
不入库。放到项目根目录后先跑一次 `./ll-killer init`，生成它要用的 `build-aux/`
（那是工具的产物，和工具本身一样不入库）：

```bash
# 先编宿主侧助手，linglong.yaml 会把它和主程序装到一起
cd linyapsd && ./tools/build-deps.sh && zig build -Doptimize=ReleaseSmall && cd ..

flutter build linux --release
./ll-killer layer build -o linyaps-seal.layer
ll-cli install ./linyaps-seal.layer -y     # 需要桌面上的 polkit 授权确认
ll-cli run io.github.leleya-x.linyaps-seal
ll-cli uninstall io.github.leleya-x.linyaps-seal
```

几点注意：

- Flutter 侧必须在**宿主机上**预先构建。ll-killer 的构建环境在用户命名空间里，flutter 会因
  「以 root 运行」拒绝构建，且 SDK 的 include 路径在映射后的 rootfs 里断链。
- **linyapsd 也要先编好**。`linglong.yaml` 里这一步是硬检查：产物不在就直接报错退出，
  不会装出一个没有穿透能力的包。
- `linglong.yaml` 的 `build` 段把整个 bundle 装到 `$PREFIX/bin/` 下。**不要**摊到 `$PREFIX/`，
  否则 `lib/`、`data/` 会被叠加到容器根目录，覆盖关键路径。
- 桌面入口与图标见下面「[桌面入口与图标](#桌面入口与图标)」，源文件在 `packaging/`。
- `ll-cli install` 走 polkit 的 `auth_admin`，必须有桌面上的密码框被应答，否则报
  `Error 9: polkit check failed`；非交互 shell 里调用会直接失败。
- `org.deepin.base/25.2.2` 已提供 Flutter Linux 桌面端所需的全部库（GTK3、glib、cairo、pango、
  harfbuzz、epoxy 等），不需要额外 runtime。
- 若 `flutter build` 报 `CMakeCache.txt ... is different than the directory`，是构建缓存被
  ll-killer 环境污染了，删掉 `build/linux` 重建即可。

### 桌面入口与图标

两者的源文件都在 [`packaging/`](packaging/)，`linglong.yaml` 把它们装到
`$PREFIX/share/{applications,icons}`。玲珑会把 `files/share` 下的这两类文件导出到
`/var/lib/linglong/entries/share`（这条路径在宿主的 `XDG_DATA_DIRS` 里），
应用因此才出现在启动器里、窗口才认得出自己的图标。缺了它，包能跑，但启动器里找不到。

- `packaging/io.github.leleya-x.linyaps-seal.desktop` 里的 `Exec=` 写的是**包内**路径。
  打成包时 ll-killer 会自动改写成 `Exec=/usr/bin/ll-cli run <id> -- <原路径>`，
  并补上 `X-linglong=`（`TryExec=/usr/bin/ll-cli` 由玲珑在安装时加）。
  **别在这儿手写 `ll-cli`**，会被再套一层。
- `packaging/linyaps-seal.svg` 是图标的源文件，改了要跑 `packaging/render-icons.sh`
  重出各尺寸 PNG。PNG 是入库的，不在打包时现渲染：构建容器里不保证有 `rsvg-convert`，
  与其让打包依赖一个不一定在的工具，不如把成品放进来。脚本同时也是校验手段 ——
  跑完 `git status` 干净，就说明 PNG 和 SVG 对得上。
- `Icon=` 与图标文件名都用包 ID，启动器靠它找到图标；窗口这边另有一条线 ——
  窗口的 GTK application-id 跟着上游，是 `io.mozixun.linyaps_seal`，与包 ID 不同名，
  所以 desktop 里写了 `StartupWMClass=` 把窗口认领回本入口。少了这一行，
  任务栏认不出窗口属于谁，图标会退回通用图标。
- 同一步里还会把 `LICENSE` 拷到包内 `share/doc/linyaps-seal/`。本项目按 GPLv2 分发，
  该许可要求随二进制附上全文；不装的话，拿到包的人手上就没有本该随附的那一份。

### 容器内的数据来源

`/var/lib/linglong/states.json` 在玲珑容器里拿不到（目录不存在，且 `/var/lib` 只读挂载），
宿主二进制也不能直接在容器里执行（`ll-cli` 会缺 `libostree-1.so.1` 等宿主库）。
可用的突破口是玲珑容器与宿主机共享 `$HOME`，也共享 session bus 的 socket
（容器内实测 `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`）。

于是应用启动时会在宿主 `$HOME` 下部署一个小的 D-Bus 助手
[`linyapsd`](linyapsd/)（Zig 写的，完全静态链接），并在
`~/.local/share/dbus-1/services/` 放一份最标准的服务文件，
由宿主 session bus 按需把它拉起来，替容器读 states.json。
**数据经 D-Bus 返回值直传，不落盘中转文件**；助手的接口刻意做窄，只有
只读查询，没有任何能改动宿主数据的方法。而且用完即走：调用方（也就是本应用）
全部退出后，助手会自己从总线上消失，不在宿主上留常驻进程。
详细设计与边界见 [linyapsd/README.md](linyapsd/README.md)。

助手装在 `~/.local/share/linyapsd/` —— **路径里不带本应用的 ID**：它是个通用的
宿主侧扩展，不算本应用的私有部件，别的玲珑应用也可以往这儿装、也都能用同一份。
落点既然是共用的，就不能无脑覆盖，应用启动时会把自己带的版本和落点上那份
（`linyapsd --version`）比一比，只有自己这份更新才装；换新版本前会先请旧实例
`Quit` 让位，否则文件换了而旧进程还占着 bus name，调用照旧由它响应，换了等于没换。
**这条规则同时也是一处坑**：助手版本跟应用一起走，若只改了助手的接口却没让版本号变新，
落点上那份旧的就会被当成"一样新"而留着，新方法在它那儿是未知方法 —— 表现是图标悄悄退回
商店那份，从外面看不出是没换上去。所以助手的接口一改，`linyapsd/build.zig.zon` 的
`.version` 就要跟着往上走。

列表里的应用图标走的是同一条链路：`/var/lib/linglong/entries/share` 是启动器看到的那份导出，
容器里同样没有，于是交给助手连图标字节一起读回来。相比去问玲珑商店要图标地址，
它离线也在，而且商店不认的包（本地构建、侧载的）一样有图标；商店那边只在本地没有图标时补位。

**只有这一条链路。** 即便应用就跑在宿主机上、`/var/lib/linglong/states.json`
本来就读得到，也照样走 D-Bus 去找 linyapsd —— 留一条"这次能直读就直读"的旁路，
等于让两种环境下的行为分叉：原生调得好好的，进容器才暴露问题；而且两条路各有各的
失败方式，排查时还得先猜走的是哪条。

`linyapsd` 是独立仓库 <https://github.com/leleya-X/Linyapsd>，主仓库里通过 `.gitignore` 排除；打包前需先在 `linyapsd/` 下
构建好产物（见其 README），`linglong.yaml` 会把它和主程序装进同一个目录。

要清理：

```bash
rm -f  ~/.local/share/dbus-1/services/io.github.leleya_x.Linyapsd.service
rm -rf ~/.local/share/linyapsd
```

（落点是共用的，删之前先确认没有别的应用还在用它。）

## 来源与许可

本项目是 [LFRon/Linyaps-Seal](https://github.com/LFRon/Linyaps-Seal) 的分支，沿用上游的名称与
Dart 包名 `linyaps_seal`，上游版权归原作者。按上游的 **GPLv2** 许可分发，[LICENSE](LICENSE) 全文保留。
本分支仓库在 <https://github.com/leleya-X/Linyaps-Seal>。

本分支相对上游的修改（GPLv2 要求的修改标注）：

- 命名一律跟随上游：Dart 包名与二进制名 `linyaps_seal`、窗口标题 `linyaps-seal`、
  GTK application-id `io.mozixun.linyaps_seal` 都原样保留，`linux/` 下与上游一字不差，
  将来同步上游不必在这些地方解冲突
- 唯一挪动的是**玲珑包 ID**：`io.github.leleya-x.linyaps-seal`。玲珑包 ID 是全系统
  唯一的键，沿用上游的会让两个包互相顶掉，装不了同一个系统上
- 新增 `linyapsd/`（独立仓库 <https://github.com/leleya-X/Linyapsd>）：宿主侧 D-Bus 助手，替容器读
  `/var/lib/linglong/states.json`、读 `/var/lib/linglong/entries/share` 下导出的桌面条目与图标，
  并跑白名单内的 `ll-cli` 只读子命令
- 新增 `lib/utils/Backend_API/host_bridge.dart`：把助手部署到宿主 `$HOME`、
  写 D-Bus 服务文件并唤醒它
- `lib/utils/Backend_API/Linyaps_CLI_API/linyaps_cli_helper.dart`：states.json 改为经
  `HostBridge.readStates()` 取（一律走 D-Bus，不因应用跑在宿主机上就直读原路径）
- 新增 `lib/utils/config_classes/linyaps_entry.dart`（宿主导出的桌面条目）与
  `lib/utils/generic_widgets/linyaps_app_icon.dart`（本地图标字节优先、其次商店链接、
  最后通用图标）：应用图标改用本地那份，商店只在本地没有图标时补位
- `lib/utils/Global_Variables/installed_apps.dart`：拆成"挂本地图标"与"补商店图标"两步。
  同时修掉一处丢数据的 bug —— 原先取图标会用商店响应**重建整个列表**，
  商店不认的应用（本地构建、侧载的）会因此从列表里消失；
  现在商店调用只填图标地址，不碰列表本身
- `lib/utils/Backend_API/Linyaps_Store_API/linyaps_store_api.dart`：`updateAppIcon` 改为
  `fetchAppIconUrls`，只返回 `应用 ID -> 图标地址`，不再改动传入的列表
- 新增 `lib/pages/startup_error/`：启动取数失败时把原因直接显示出来，而不是给一张空列表。
  相应地，各层不再把出错压成 null 或空集合 —— 读不到和"确实没有"在界面上长得一样，
  兜成一个就再也分不清是哪种
- 早期本分支用 systemd 用户服务把 states.json 复制进共享缓存，已改为上面的 D-Bus 方案
- 新增 `linglong.yaml` 打包配置。配套的 ll-killer 是外部工具，不入库；它生成的
  `build-aux/` 脚本同理，已由 `.gitignore` 排除，首次打包前跑一次 `./ll-killer init`
- `pubspec.lock` 由忽略改为入库：这是应用不是库，锁文件该跟着走，别人 clone 下来
  才能装出一样的依赖树
- 新增 `.gitattributes`：统一按 LF 入库检出，避免 Windows 上 clone 出来的
  shell 脚本带 CRLF 后无法执行
- 新增 `packaging/`：自制的应用图标（SVG 源 + 各尺寸 PNG）与桌面入口，
  由 `linglong.yaml` 装进包内 `share/`，否则装完在启动器里找不到这个应用
- 移除 Android / iOS / macOS / Windows / Web 平台目录及相关配置，以及只为 iOS 图标准备的
  `cupertino_icons` 依赖
- 移除上游两个没有任何引用的模板遗留文件：`lib/utils/config_classes/permissions/config_permissions.dart`
  （空壳类）与 `lib/utils/page_utils/middle_page/dropdown_menu.dart`（全仓库搜不到 import）
- 移除未使用的 deb/apt 打包脚手架（`Makefile`、`apt.conf.d/`、`sources.list.d/` 等）
- 清理死代码（`config_permissions.dart`、`dropdown_menu.dart`、模板 `widget_test.dart` 等）
- 更新检查由 gitee API 改为 GitHub Releases API
