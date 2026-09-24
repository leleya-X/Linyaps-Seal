#!/bin/bash
# 把预构建产物、桌面入口、图标、许可证装进包内的 $PREFIX。
#
# 由 linglong.yaml 的 build 调用：
#   ./packaging/install-prebuilt.sh "$PREFIX"
# 也能在宿主机上拿个空目录试跑（不起容器，只验这一步本身）：
#   mkdir -p /tmp/t && ./packaging/install-prebuilt.sh /tmp/t
#
# 这里只「装」不「编」：产物从 linglong/sources/ 下那份预构建包里取，
# 生成方式见 packaging/make-prebuilt.sh。
# **没有**「源不在就拿本地 build/ 目录顶上」的退路 —— 那种退路只在打包机上走得通，
# 到了别人的构建机上要么直接失败，要么装出别的东西，而且两种情况都要过一阵子才现形。
set -euo pipefail

PREFIX_DIR=${1:-}
if [ -z "$PREFIX_DIR" ]; then
    echo "用法: $0 <安装前缀>（玲珑里就是 \$PREFIX）" >&2
    exit 1
fi

ROOT=$(dirname "$(readlink -f "$0")")/..
cd "$ROOT"

# sources 目录里应当只有一份 tar.gz，就是这份预构建包。
# 一份都没有，说明源没拉下来；多于一份，说明 linglong.yaml 被改出了别的源 ——
# 两种都不去猜该用哪份：猜错的表现是"编出来的是一个内容和源对不上的包"，
# 而它从构建日志上看不出任何异常
SRC=""
for f in linglong/sources/*.tar.gz; do
    [ -e "$f" ] || continue     # 一个都没匹配上时 glob 会原样留着，跳过它
    if [ -n "$SRC" ]; then
        echo "linglong/sources 下有不止一份 tar.gz，不知道该用哪份: $SRC 与 $f" >&2
        exit 1
    fi
    SRC=$f
done
if [ -z "$SRC" ]; then
    echo "linglong/sources 下没有预构建包 —— 它由 linglong.yaml 的 sources 拉取。" >&2
    echo "本地要重新生成见 packaging/make-prebuilt.sh" >&2
    exit 1
fi
echo "预构建包: $SRC"

# 整个 bundle 装到 files/bin/ 下，避免 lib/、data/ 被叠加到容器根目录
#
# --no-same-owner: 不去照归档里的属主 chown。构建容器里是 root，tar 默认就会去动属主，
# 而归档里的那个 uid 在容器的用户命名空间里常常没被映射，chown 直接 EINVAL 把构建打断。
# 包里的文件归谁是这一步之后的事，跟归档里记的无关。
mkdir -p "$PREFIX_DIR/bin"
tar --no-same-owner -xzf "$SRC" -C "$PREFIX_DIR/bin"

# 装完先确认该在的都在：空包、或者打的时候漏了助手，都能平静地过掉 tar 那一步
test -x "$PREFIX_DIR/bin/linyaps_seal" || {
    echo "$SRC 里没有 linyaps_seal，这不是一份能用的预构建包" >&2
    exit 1
}
# 助手与主程序同目录: 容器内由 host_bridge.dart 找到它，再部署到宿主 $HOME
test -x "$PREFIX_DIR/bin/linyapsd" || {
    echo "$SRC 里没有 linyapsd，装出来的包会缺穿透能力" >&2
    exit 1
}

# 桌面入口与图标。装到 $PREFIX/share 下，玲珑会把它们导出到
# /var/lib/linglong/entries/share（宿主的 XDG_DATA_DIRS 里有它），
# 这样应用才出现在启动器里、窗口才认得出自己的图标。
#
# desktop 里写的是包内可执行文件路径，build-aux/post-setup.sh 会改写成
# ll-cli run 的调用形式并补 X-linglong=，别在这儿手写 ll-cli。
test -f packaging/io.github.leleya-x.linyaps-seal.desktop || {
    echo "缺少 packaging/io.github.leleya-x.linyaps-seal.desktop" >&2
    exit 1
}
test -d packaging/icons/hicolor || {
    echo "缺少 packaging/icons/hicolor，跑一下 packaging/render-icons.sh" >&2
    exit 1
}

mkdir -p "$PREFIX_DIR/share/applications" "$PREFIX_DIR/share/icons"
cp packaging/io.github.leleya-x.linyaps-seal.desktop \
   "$PREFIX_DIR/share/applications/io.github.leleya-x.linyaps-seal.desktop"
cp -r packaging/icons/hicolor "$PREFIX_DIR/share/icons/"

# 再放一份矢量图。各家桌面按 DPI 挑尺寸时优先用 PNG，
# 挑不到合适的档位就落回 scalable，有它就不会退到通用图标
mkdir -p "$PREFIX_DIR/share/icons/hicolor/scalable/apps"
cp packaging/linyaps-seal.svg \
   "$PREFIX_DIR/share/icons/hicolor/scalable/apps/io.github.leleya-x.linyaps-seal.svg"

# 许可证全文。本项目按 GPLv2 分发，该许可要求随二进制分发时附上全文；
# 不装的话，拿到这个包的人手上就没有本该随附的那份许可证。
# (本项目相对上游的修改标注见仓库 README)
mkdir -p "$PREFIX_DIR/share/doc/linyaps-seal"
cp LICENSE "$PREFIX_DIR/share/doc/linyaps-seal/LICENSE"

echo "已装入 $PREFIX_DIR: bin/{linyaps_seal,linyapsd,...}, share/{applications,icons,doc}"
