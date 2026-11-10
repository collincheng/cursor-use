#!/usr/bin/env bash
# 重新生成应用图标 Resources/AppIcon.icns(生成结果已提交进仓库,平时不需要运行)。
# 想改图标样式时,编辑 scripts/make-icon.swift,再运行本脚本。
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET" Resources
rm -f "$ICONSET"/*.png

swift scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

echo "已生成: Resources/AppIcon.icns"
ls -lh Resources/AppIcon.icns
