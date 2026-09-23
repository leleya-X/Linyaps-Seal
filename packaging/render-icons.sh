#!/bin/bash
# 由 linyaps-seal.svg 渲染出各尺寸的 PNG 图标。
#
#   ./packaging/render-icons.sh
#
# PNG 是**入库**的，不是在打包时现渲染的：玲珑的构建容器（org.deepin.base）
# 里没有把握一定有 rsvg-convert，与其让打包依赖一个不一定在的工具，
# 不如把成品放进来。
# 代价是改了 SVG 得记得重跑本脚本 —— 所以它同时也是一致性检查：
# 跑完 `git status` 干净，就说明 PNG 和 SVG 是对得上的。
#
# 需要 rsvg-convert（Arch: extra/librsvg）。
set -euo pipefail

CWD=$(dirname "$(readlink -f "$0")")
SRC="$CWD/linyaps-seal.svg"
APPID="io.github.leleya-x.linyaps-seal"

# 16 给面板和列表，512 给商店/预览这类大图，
# 中间几个是各家桌面按 DPI 挑的常用档位
SIZES=(16 24 32 48 64 128 256 512)

if ! command -v rsvg-convert >/dev/null; then
    echo "缺少 rsvg-convert，装一下 librsvg（Arch: pacman -S librsvg）" >&2
    exit 1
fi

for s in "${SIZES[@]}"; do
    out="$CWD/icons/hicolor/${s}x${s}/apps/$APPID.png"
    mkdir -p "$(dirname "$out")"
    rsvg-convert "$SRC" -o "$out" -w "$s" -h "$s"
    echo "  $out"
done

echo "完成，共 ${#SIZES[@]} 个尺寸"
