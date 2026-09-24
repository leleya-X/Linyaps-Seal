#!/bin/bash
# 打出「预构建产物」包 —— 打包时构建容器要装的就是它。
#
#   ./packaging/make-prebuilt.sh
#
# 产物：dist/linyaps-seal-<应用版本>-<架构>-prebuilt.tar.gz
#
# 为什么产物在容器外编：玲珑的构建容器里编不了这两份 ——
#   - Flutter 桌面端：构建跑在用户命名空间里，flutter 会因「以 root 运行」拒绝构建，
#     而且 SDK 的 include 路径在映射后的 rootfs 里断链
#   - linyapsd：按 musl 静态编，容器里没有 zig，也没有编 libdbus 静态库的那套工具
# 所以先在这里编好，再由 packaging/install-prebuilt.sh（构建容器里跑的那一步）
# 从 dist/ 取走 —— 整个工程目录是挂载进容器的，path 直通，不联网、不需要发布。
#
# 换版本、或者改了任何会进包的东西之后都要重跑一次：产物是工作区里一个
# 不受版本约束的文件，忘了重打就会装进上一版的程序（install-prebuilt.sh 里
# 有版本核对，对不上会直接报错，不会静悄悄地装错）。
set -euo pipefail

ROOT=$(dirname "$(readlink -f "$0")")/..
cd "$ROOT"

# 版本号只认 pubspec.yaml（见 README「版本号」）。不从别处抄一份，
# 抄出来的那份迟早和真源对不上，而两处都不会报错
VERSION=$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' pubspec.yaml)
if [ -z "$VERSION" ]; then
    echo "pubspec.yaml 里读不到 version —— 那是应用版本号的唯一真源" >&2
    exit 1
fi
# 版本号会进文件名和 URL。pubspec 允许写 0.0.18+2 这种构建号，
# 带加号的名字放进 URL 里会被转义、肉眼也容易看错，干脆在这儿挡住
case "$VERSION" in
    *+*)
        echo "pubspec.yaml 的 version 带了构建号（$VERSION）。" >&2
        echo "这个包只用前半段，请把它改成 ${VERSION%%+*} 之后再打" >&2
        exit 1
        ;;
esac

command -v flutter >/dev/null || { echo "缺少 flutter" >&2; exit 1; }
echo "==> Flutter 桌面端 (release)"
flutter build linux --release

# 架构从产物目录名推，不另问 uname —— 编出来在哪个目录里，它就是给哪个架构的。
# 同时存在多个（以前编过别的架构、残留没清）就不猜，那正是"打包时想的和实际编的
# 不是同一份"的老路
BUNDLES=(build/linux/*/release/bundle)
if [ "${#BUNDLES[@]}" -ne 1 ] || [ ! -d "${BUNDLES[0]}" ]; then
    echo "build/linux 下应当只有一个 <架构>/release/bundle，实际是: ${BUNDLES[*]}" >&2
    echo "（残留的旧架构目录先删掉，不确定该留哪个就 flutter clean）" >&2
    exit 1
fi
BUNDLE=${BUNDLES[0]}
ARCH_DIR=$(basename "$(dirname "$(dirname "$BUNDLE")")")
case "$ARCH_DIR" in
    x64)   ARCH=x86_64  ;;
    arm64) ARCH=aarch64 ;;
    *)
        echo "认不出 Flutter 的架构目录名 '$ARCH_DIR'，不硬猜一个写进文件名" >&2
        exit 1
        ;;
esac

echo "==> linyapsd (宿主侧助手)"
if [ ! -d linyapsd ]; then
    echo "缺 linyapsd/ —— 它是独立仓库 <https://github.com/leleya-X/Linyapsd>，" >&2
    echo "clone 到本目录下再打（主仓库用 .gitignore 排除了它）" >&2
    exit 1
fi
command -v zig >/dev/null || { echo "缺少 zig（0.16+）" >&2; exit 1; }
( cd linyapsd && ./tools/build-deps.sh && zig build -Doptimize=ReleaseSmall )
HELPER=linyapsd/zig-out/bin/linyapsd
[ -x "$HELPER" ] || { echo "$HELPER 没有生成" >&2; exit 1; }
# 助手的版本号是它自己的，不跟着应用版本走（改了接口就必须把它抬上去，
# 否则宿主上那份永远换不掉，见 README）。这里只是把它打出来留个记录
echo "    助手自报版本: $("$HELPER" --version)"

echo "==> 打包"
OUT="dist/linyaps-seal-$VERSION-$ARCH-prebuilt.tar.gz"
mkdir -p dist
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# 包内布局 == 装好之后 $PREFIX/bin/ 的布局：bundle 的内容平铺，助手也放在这一层。
# linyapsd 必须和 linyaps_seal 同目录 —— host_bridge.dart 只在可执行文件旁边找它，
# 找不到就直接报错，没有"再去 /usr/bin 碰碰运气"那种退路。
cp -a "$BUNDLE"/. "$STAGE"/
install -m755 "$HELPER" "$STAGE"/linyapsd

# 归档里的属主固定成 0:0，不写打包者的 uid。
# 构建容器里是以 root 解这个包的，tar 会照着归档里的属主去 chown ——
# 而那个 uid 在容器的用户命名空间里往往没被映射，chown 报 EINVAL，
# 整个构建就卡在这个谁也没想过的位置上。（这不是假设，是踩过的。）
# 属主本来也不该由打包机决定：包里的文件归谁，是打包那一步的事。
tar --owner=0 --group=0 --numeric-owner -czf "$OUT" -C "$STAGE" .

SUM=$(sha256sum "$OUT" | cut -d' ' -f1)
echo
echo "产物:   $OUT ($(du -h "$OUT" | cut -f1))"
echo "sha256: $SUM"
echo
echo "打包时构建容器会从 dist/ 取它（见 linglong.yaml 的 build）。"
echo "接下来直接跑 ./ll-killer layer build 或 ll-builder build 即可，不需要再做什么。"
