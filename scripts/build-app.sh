#!/usr/bin/env bash
# 构建并打包成 build/CursorUsage.app
#
# 环境变量:
#   VERSION            版本号,如 1.2.3。默认取最近的 git tag(去掉前缀 v),没有 tag 则为 0.1.0
#   BUILD              构建号。默认为 git 提交数
#   UNIVERSAL=1        同时构建 arm64 和 x86_64 并合并成通用二进制(发布用)
#   CODESIGN_IDENTITY  签名身份。默认自动使用名为 "CursorUsage Dev" 的本地证书,没有则 ad-hoc 签名
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="CursorUsage"
BUNDLE_ID="com.colin.cursor-usage"
MIN_MACOS="13.0"
APP="build/${APP_NAME}.app"

# ---------- 版本 ----------
if [ -z "${VERSION:-}" ]; then
    tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    VERSION="${tag#v}"
    VERSION="${VERSION:-0.1.0}"
fi
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
echo "版本: ${VERSION} (build ${BUILD})"

# ---------- 编译 ----------
# 用 --triple 而不是 --arch:后者要求完整 Xcode,前者只需 Command Line Tools。
build_arch() {
    local triple="$1-apple-macosx${MIN_MACOS}"
    swift build -c release --triple "$triple" >&2
    echo "$(swift build -c release --triple "$triple" --show-bin-path)/${APP_NAME}"
}

if [ "${UNIVERSAL:-0}" = "1" ]; then
    arm="$(build_arch arm64)"
    x86="$(build_arch x86_64)"
    mkdir -p build/universal
    BIN="build/universal/${APP_NAME}"
    lipo -create "$arm" "$x86" -output "$BIN"
    echo "通用二进制: $(lipo -archs "$BIN")"
else
    swift build -c release
    BIN="$(swift build -c release --show-bin-path)/${APP_NAME}"
fi

# ---------- 打包 ----------
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/${APP_NAME}"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# ---------- 签名 ----------
#  - CODESIGN_IDENTITY 优先;
#  - 否则自动使用名为 "CursorUsage Dev" 的本地证书(固定身份,重新打包后签名不变,
#    钥匙串里点过一次"始终允许"就长期有效);
#  - 都没有则退回 ad-hoc 签名(每次打包签名都会变,钥匙串会重新询问)。
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ] && security find-identity -p codesigning 2>/dev/null | grep -q '"CursorUsage Dev"'; then
    IDENTITY="CursorUsage Dev"
fi

if [ -n "$IDENTITY" ] && codesign --force --sign "$IDENTITY" "$APP" >/dev/null 2>&1; then
    echo "签名: $IDENTITY(固定身份)"
else
    [ -n "$IDENTITY" ] && echo "警告: 使用 \"$IDENTITY\" 签名失败,退回 ad-hoc"
    codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "警告: codesign 失败,通知/开机自启可能不可用"
    echo "签名: ad-hoc(每次打包签名会变,钥匙串可能重新询问;创建名为 \"CursorUsage Dev\" 的代码签名证书可避免)"
fi

echo "已生成: $APP"
echo "运行:   open $APP"
echo "安装:   cp -R $APP /Applications/"
