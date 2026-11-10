#!/usr/bin/env bash
# 生成某个版本的发布说明(Markdown,输出到 stdout):安装提示 + 与上一个 tag 之间的提交列表。
#
# 用法:  ./scripts/release-notes.sh v1.2.3
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="${1:?用法: release-notes.sh <tag>}"
VERSION="${TAG#v}"
ZIP="CursorUsage-${VERSION}-macOS-universal.zip"

# 上一个 tag(不存在则从第一个提交开始)
PREV="$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || true)"
RANGE="${PREV:+${PREV}..}${TAG}"

cat <<EOF
## 安装

1. 下载 \`${ZIP}\`,解压得到 \`CursorUsage.app\`,拖到「应用程序」。
2. 首次打开会被 macOS 拦截(应用没有 Apple 开发者签名):
   - 打开「系统设置 → 隐私与安全性」,拉到底部点「仍要打开」;或在终端执行:
     \`xattr -dr com.apple.quarantine /Applications/CursorUsage.app\`
3. 打开后点菜单栏图标,粘贴你的 Cursor User API Key(\`crsr_\` 开头)。

校验:\`shasum -a 256 -c ${ZIP}.sha256\`

> 升级到新版本后,钥匙串可能再询问一次授权,点「始终允许」即可(应用是 ad-hoc 签名,每个版本的签名身份不同)。
> 支持 macOS 13 及以上,Apple 芯片和 Intel 都可用。

## 变更

EOF

# 先存进变量再判断:`git log | grep -q` 在 pipefail 下会因 SIGPIPE 误判为失败
CHANGES="$(git log --pretty='- %s' "${RANGE}")"
echo "${CHANGES:-- 无}"
