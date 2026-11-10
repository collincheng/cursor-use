#!/usr/bin/env bash
# 构建并打包成 build/CursorUsage.app(ad-hoc 签名,仅供自用)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="CursorUsage"
BUNDLE_ID="com.colin.cursor-usage"
APP="build/${APP_NAME}.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/${APP_NAME}"

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
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# 签名身份:
#  - 环境变量 CODESIGN_IDENTITY 优先;
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
