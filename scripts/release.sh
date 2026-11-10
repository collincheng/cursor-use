#!/usr/bin/env bash
# 发布新版本:检查 → 自检 → 打 tag → 推送 tag。推送 tag 后由 GitHub Actions 自动打包并创建 Release。
#
# 用法:  ./scripts/release.sh 1.2.3        (预发布: 1.2.3-beta.1)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?用法: release.sh <版本号,如 1.2.3>}"
VERSION="${VERSION#v}"
TAG="v${VERSION}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    echo "错误: 版本号需要形如 1.2.3 或 1.2.3-beta.1" >&2; exit 1
fi
if [ "$(git branch --show-current)" != "main" ]; then
    echo "错误: 请在 main 分支上发布" >&2; exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "错误: 工作区有未提交的改动,请先提交" >&2; exit 1
fi
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "错误: tag ${TAG} 已存在" >&2; exit 1
fi

git fetch origin --quiet
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
    echo "错误: 本地 main 与 origin/main 不一致,请先推送或拉取" >&2; exit 1
fi

echo "自检..."
swift build >/dev/null
.build/debug/CursorUsage --selftest | tail -1

echo "创建并推送 ${TAG}"
git tag -a "$TAG" -m "CursorUsage ${VERSION}"
git push origin "$TAG"

echo "已推送。Actions 会自动打包并创建 Release:"
echo "  $(git remote get-url origin | sed -E 's#\.git$##; s#^git@github.com:#https://github.com/#')/actions"
