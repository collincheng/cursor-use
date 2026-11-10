#!/usr/bin/env bash
# 打包发布产物到 dist/:通用二进制的 .app 压缩包 + SHA-256 校验文件。
#
# 用法:  VERSION=1.2.3 ./scripts/package-release.sh
# 版本号未指定时与 build-app.sh 一致(最近的 git tag)。
set -euo pipefail
cd "$(dirname "$0")/.."

export UNIVERSAL=1
./scripts/build-app.sh

# 从打包好的 Info.plist 读回版本号,保证文件名与应用内显示一致
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/CursorUsage.app/Contents/Info.plist)"
ZIP="CursorUsage-${VERSION}-macOS-universal.zip"

rm -rf dist
mkdir -p dist
# ditto 会保留 .app 的结构和签名信息,比 zip 命令可靠
ditto -c -k --sequesterRsrc --keepParent build/CursorUsage.app "dist/${ZIP}"
(cd dist && shasum -a 256 "${ZIP}" > "${ZIP}.sha256")

echo
echo "发布产物:"
ls -lh dist
cat "dist/${ZIP}.sha256"
