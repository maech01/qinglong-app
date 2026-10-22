#!/usr/bin/env bash
# 把本地优化后的代码推到 https://github.com/maech01/qinglong-app
#
# 需要一个有 contents:write 权限的 PAT，通过环境变量 GITHUB_TOKEN 提供。
# 令牌只用于这一次 push 的 URL，不会写进 .git/config。
set -euo pipefail

cd "$(dirname "$0")"

REPO="maech01/qinglong-app"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "缺少 GITHUB_TOKEN。" >&2
  echo "在 设置 → 环境变量 里新建 GITHUB_TOKEN（GitHub PAT，勾选 repo 或 contents:write）。" >&2
  exit 1
fi

# 只校验有没有推送权限，不打印令牌
echo "==> 校验仓库访问权限"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO")
echo "    /repos/$REPO -> HTTP $HTTP"
if [ "$HTTP" = "401" ]; then
  echo "令牌无效或已过期。" >&2
  exit 1
fi
if [ "$HTTP" = "404" ]; then
  echo "令牌看不到该仓库：确认它有 repo 权限，且仓库名拼写正确。" >&2
  exit 1
fi

# origin 指向上游作者仓库，改名保留；新建 origin 指向自己的仓库
if [ "$(git remote get-url origin 2>/dev/null || true)" != "https://github.com/$REPO.git" ]; then
  if git remote | grep -qx upstream; then
    git remote set-url upstream "https://github.com/ayoulx/qinglong-app.git"
  else
    git remote rename origin upstream 2>/dev/null || true
  fi
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/$REPO.git"
fi

echo "==> 推送 main"
GIT_TERMINAL_PROMPT=0 git push \
  "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git" \
  HEAD:main

echo
echo "推送完成：https://github.com/$REPO"
echo "Actions：https://github.com/$REPO/actions"
echo "APK（构建完成后）：https://github.com/$REPO/releases/download/latest/app-release.apk"
