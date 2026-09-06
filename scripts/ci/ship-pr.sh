#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ship-pr.sh — 全自动 PR 交付与生命周期闭环脚本 (Ship & Auto-Cleanup)
#
# 适用范围：Codex / Claude Code / Antigravity / 终端开发者
# 行为准则：
#   1. 检查工作区干净后 push 分支并创建 GitHub PR
#   2. 阻塞监听 GitHub Actions CI
#   3. 【CI 全绿】：自动 Squash Merge -> 切回主仓库更新 main -> 安全删除当前 worktree 与分支
#   4. 【CI 失败】：严格熔断！严禁合并、严禁删分支、严禁删 worktree，自动抓取失败日志并报错退出
# ==============================================================================

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" = "main" ]; then
  echo "❌ 错误：不能在 main 分支上执行 ship-pr！" >&2
  exit 1
fi

# 检查工作区是否有未跟踪或未提交的修改
if ! git diff-index --quiet HEAD --; then
  echo "❌ 错误：当前工作区有未提交的修改，请先 commit 或 stash 后再提 PR！" >&2
  exit 1
fi

CURRENT_WORKTREE="$(git rev-parse --show-toplevel)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
MAIN_REPO="$(cd "$GIT_COMMON_DIR/.." && pwd)"

echo "🚀 [1/4] 推送分支到远端: $CURRENT_BRANCH ..."
git push -u origin "$CURRENT_BRANCH"

echo "📝 [2/4] 创建/确认 GitHub Pull Request ..."
# 如果已存在 PR 则复用，否则创建
PR_URL="$(gh pr view --json url -q .url 2>/dev/null || true)"
if [ -z "$PR_URL" ]; then
  PR_URL="$(gh pr create --fill)"
fi
echo "🔗 PR 地址: $PR_URL"

echo "⏳ [3/4] 正在阻塞监听 GitHub Actions 云端 CI Checks..."
# 刚创建 PR 时 GitHub Actions 可能需要几秒注册 jobs
for i in {1..10}; do
  if gh pr checks >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! gh pr checks --watch; then
  echo "" >&2
  echo "🚨 [CI 失败熔断保护触发] ────────────────────────────────────────" >&2
  echo "• 云端 CI 未通过！严格禁止合并 PR，严禁删除分支与 Worktree！" >&2
  echo "• 当前工作区完整保留在: $CURRENT_WORKTREE" >&2
  echo "• 正在提取失败检查的日志摘要:" >&2
  echo "─────────────────────────────────────────────────────────────────" >&2
  gh run view --log-failed 2>/dev/null | tail -n 40 || true
  exit 1
fi

echo "✅ 云端 CI 全部通过 (All Checks Passed)！"

echo "🔀 [4/4] 自动合并 PR 并清理现场..."
gh pr merge --squash --delete-branch

if [ "$CURRENT_WORKTREE" != "$MAIN_REPO" ]; then
  echo "🧹 切回主仓库 ($MAIN_REPO) 同步最新 main..."
  cd "$MAIN_REPO"
  git fetch origin main
  git checkout main
  git pull origin main

  echo "🗑️ 安全移除 Worktree 与本地分支..."
  git worktree remove "$CURRENT_WORKTREE" --force || true
  git branch -D "$CURRENT_BRANCH" || true
else
  echo "主仓库同步最新 main..."
  git fetch origin main
  git checkout main
  git pull origin main
  git branch -D "$CURRENT_BRANCH" || true
fi

echo "🎉 [全部完成] PR 已自动合并至 main，远端与本地分支已删除，Worktree 工作区已干净清理！"
