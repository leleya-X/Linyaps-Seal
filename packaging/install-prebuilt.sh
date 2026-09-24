#!/bin/bash
# 把预构建产物、桌面入口、图标、许可证装进包内的 $PREFIX。
#
# 由 linglong.yaml 的 build 调用：
#   ./packaging/install-prebuilt.sh "$PREFIX"
# 也能在宿主机上拿个空目录试跑（不起容器，只验这一步本身）：
#   mkdir -p /tmp/t && ./packaging/install-prebuilt.sh /tmp/t
#
# 这里只「装」不「编」：产物是 packaging/make-prebuilt.sh 在宿主上打好的那一份，
# 就在工作区的 dist/ 下。构建容器能看到它，是因为整个工程目录是挂载进去的 ——
# 没有任何一件输入要联网去拿。
# **没有**「没有产物就拿 build/ 里的半成品顶上」的退路：那种退路会装出一个
# 缺部件或者版本对不上的包，而且要等装完才发现。
set -euo pipefail

PREFIX_DIR=${1:-}
if [ -z "$PREFIX_DIR" ]; then
    echo "用法: $0 <安装前缀>（玲珑里就是 \$PREFIX）" >&2
    exit 1
fi

ROOT=$(dirname "$(readlink -f "$0")")/..
cd "$ROOT"

# dist/ 下应当只有一份预构建包。
# 一份都没有，说明还没跑 make-prebuilt.sh；多于一份（换版本时旧的没删）就不去猜 ——
# 猜错的表现是"打出来的包内容和以为的不是同一份"，而构建日志上看不出任何异常
SRC=""
for f in dist/*-prebuilt.tar.gz; do
    [ -e "$f" ] || continue     # 一个都没匹配上时 glob 会原样留着，跳过它
    if [ -n "$SRC" ]; then
        echo "dist/ 下有不止一份预构建包，不知道该用哪份: $SRC 与 $f" >&2
        echo "（换版本后旧的先删掉）" >&2
        exit 1
    fi
    SRC=$f
done
if [ -z "$SRC" ]; then
    echo "dist/ 下没有预构建包，先跑一次 packaging/make-prebuilt.sh" >&2
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

# 版本对得上吗。产物来自工作区里一个不受版本约束的文件（以前靠源的 URL + sha256
# 锁住，现在没有那层了），换版本时忘了重打，装进去的就是上一版的程序 ——
# 而它照样能启动、界面照常显示，只有关于页里那个号是旧的。
# 包里 version.json 是 Flutter 打的（见 pubspec.yaml 的注释），拿它跟真源比
APP_VERSION=$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' pubspec.yaml)
BUILT_VERSION=$(sed -n 's/.*"version":"\([^"]*\)".*/\1/p' "$PREFIX_DIR/bin/data/flutter_assets/version.json")
if [ "$BUILT_VERSION" != "$APP_VERSION" ]; then
    echo "预构建包是 $BUILT_VERSION 的，pubspec.yaml 是 $APP_VERSION ——" >&2
    echo "产物过期了，重跑一次 packaging/make-prebuilt.sh" >&2
    exit 1
fi

# 架构也对一下。装错架构的包，构建这一步是成功的，要到别的机器上运行才炸
# （甚至不炸 —— 玲珑按架构挑包，这种包根本不会被选中）
case "$(uname -m)" in
    x86_64)  want=62  ;;
    aarch64) want=183 ;;
    *)       want=0   ;;    # 认不出的架构不拦，下面只校验认得出的那两种
esac
if [ "$want" != 0 ]; then
    # ELF 头偏移 18 起的两个字节是 e_machine，小端；低字节够区分这两个架构
    got=$(od -An -tu1 -j18 -N1 "$PREFIX_DIR/bin/linyaps_seal" | tr -d ' ')
    if [ "$got" != "$want" ]; then
        echo "$SRC 里的 linyaps_seal 不是 $(uname -m) 的产物（ELF e_machine=$got）" >&2
        echo "架构不对的包在别的机器上编出来照样「成功」，所以在这儿挡住" >&2
        exit 1
    fi
fi

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
