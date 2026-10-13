#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ship-pr.sh — PR 交付与生命周期闭环（Ship & Auto-Cleanup）
#
# 适用范围：Codex / Claude Code / Antigravity / 终端开发者
#
# 分阶段执行，合并与清理永远不随「提 PR」自动发生：
#   ship-pr.sh                  阶段一 · 提 PR：守卫 -> push -> 建/复用 PR -> 盯 CI -> 报告
#   ship-pr.sh merge            阶段二 · 合并：复核检查全绿 -> squash merge -> ff-only 对齐 main
#   ship-pr.sh cleanup [PR号]   阶段三 · 清理：确认 PR 已 MERGED -> 删远端分支 -> 移 worktree / 删本地分支
#   --dry-run                   可出现在任意参数位置（`merge --dry-run` 与 `--dry-run merge` 等价），
#                               只跑守卫并打印计划，不产生任何远端写操作
#
# 阶段设计要点：
#   - 阶段二只合并、不删分支。分支删除统一收进阶段三，三阶段职责互不重叠。
#   - 合并后仓库停在 main（阶段二的对齐步骤），因此 cleanup 允许在 main 上执行，
#     分支名一律从 PR 解析（headRefName），不依赖当前 checkout。
#   - mergeable 为 UNKNOWN 是 GitHub 还没算完（刚 push 时常见），轮询等待；
#     只有 CONFLICTING 才拒绝，且二者文案分开，不把"没算完"说成"有冲突"。
#   - 基线优先取 origin/main：本地 main 在多 worktree 用法下常落后于远端，
#     用过期基线会把 main 上已合入的改动误算进本分支 diff（作者/高风险文件误判）。
#
# 熔断规则（pr/merge 阶段，任何一条触发即停止，绝不合并）：
#   - 工作区不干净（含未跟踪文件，git diff-index 看不见它们，必须用 status）
#   - 提交作者邮箱与当前 git 身份不符（按 email 小写归一核对，name 差异不拦）
#   - PR 上没有任何检查（如 commit 带 [skip ci]）或任一检查非绿
#   - 改动涉及 supabase/ 或 .github/（数据库 / Edge Function / CI 高风类别）
#   - 本地 main 与远端分叉（只允许 ff-only，禁止 reset --hard）
#
# cleanup 阶段豁免以上守卫，改由阶段内熔断保护：
#   - PR 必须 MERGED；当前分支既不是 main 也不等于 PR 的 head 分支 -> 拒绝（防删错现场）；
#   - worktree 移除不带 --force（git 自身拒绝脏目录）；远端/本地分支删除均幂等。
# ==============================================================================

usage() {
  cat >&2 <<'EOF'
用法：
  ship-pr.sh                      阶段一 · 提 PR（绝不合并）
  ship-pr.sh merge                阶段二 · 合并（复核检查 -> squash merge -> 对齐 main，不删分支）
  ship-pr.sh cleanup [PR号]       阶段三 · 清理（确认 MERGED -> 删远端分支 -> 移 worktree / 删本地分支）
  --dry-run                       可出现在任意位置，只跑守卫并打印计划，不产生任何远端写操作
EOF
}

refuse() {
  echo "❌ $1" >&2
  exit 1
}

# ---------------- 参数解析（先于守卫：守卫按阶段定制） ----------------

# --dry-run 是 flag 不是位置参数：先剔除，再从剩余参数取子命令，
# 这样 `--dry-run merge` 与 `merge --dry-run` 等价，不会静默跑错阶段。
DRY_RUN=false
REMAINING=()
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  else
    REMAINING+=("$arg")
  fi
done
if [ "${#REMAINING[@]}" -gt 0 ]; then
  set -- "${REMAINING[@]}"
else
  set --
fi
ACTION="${1:-pr}"
case "$ACTION" in
  pr | merge | cleanup) ;;
  *) usage; exit 2 ;;
esac

# ---------------- 本地守卫（纯 git；pr/merge 阶段先过这里） ----------------

# orphan 分支（无提交）上 rev-parse HEAD 会失败，兜底为字面 HEAD，
# 让后续「没有任何提交」守卫给出正确拒绝而不是 set -e 直接退出 128。
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
# 路径统一规范化为物理路径（pwd -P）：macOS 上 /tmp 是 /private/tmp 的符号链接，
# --show-toplevel 返回物理路径而 cd 拼接可能保留逻辑路径，字符串比较会误判主仓库为 worktree。
CURRENT_WORKTREE="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
MAIN_REPO="$(cd "$GIT_COMMON_DIR/.." && pwd -P)"

PR_URL=""
pr_url() {
  [ -n "$PR_URL" ] || PR_URL="$(gh pr view --json url -q .url 2>/dev/null || true)"
}

if [ "$ACTION" != "cleanup" ]; then

  [ "$CURRENT_BRANCH" != "main" ] || refuse "不能在 main 分支上执行 ship-pr（cleanup 除外）"

  # 1) 工作区必须完全干净，包括未跟踪文件。
  #    git diff-index 只覆盖已跟踪文件的改动，看不见未跟踪文件——
  #    而 git worktree remove --force 会连未跟踪文件一起删掉，所以这里必须用 status。
  if [ -n "$(git status --porcelain)" ]; then
    echo "❌ 工作区不干净（含未跟踪文件），请先 commit / stash / 处理后再试：" >&2
    git status --short >&2
    exit 1
  fi

  # 2) 基线：先 fetch origin/main 取最新，优先以远端为准。
  #    本地 main 在多 worktree 用法下常落后于远端，用过期基线会把 main 上
  #    已合入的改动误算进本分支 diff，导致作者检查误伤、高风险文件检查误报。
  #    唯一例外：本地 main 含未推送的本地提交（其分叉点比 origin/main 更晚），以本地为准。
  git fetch origin main >/dev/null 2>&1 || true
  BASE_REF_O="$(git merge-base origin/main HEAD 2>/dev/null || true)"
  BASE_REF_L="$(git merge-base main HEAD 2>/dev/null || true)"
  if [ -n "$BASE_REF_O" ] && [ -n "$BASE_REF_L" ] \
     && git merge-base --is-ancestor "$BASE_REF_O" "$BASE_REF_L" 2>/dev/null; then
    BASE_REF="$BASE_REF_L"
  else
    BASE_REF="${BASE_REF_O:-$BASE_REF_L}"
  fi
  [ -n "$BASE_REF" ] || BASE_REF="HEAD"

  # 3) 分支上要有提交，且提交作者必须与当前 git 身份一致。
  #    身份只按 email 核对（规范化为小写）：email 决定提交归属哪个 GitHub 账号；
  #    name 只是显示名，同一人在不同机器/配置下大小写、显示名常有差异，
  #    "name <email>" 精确字符串匹配会误伤本人的老提交。
  AUTHOR_EMAILS="$(git log "$BASE_REF..HEAD" --format='%ae' 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
  [ -n "$AUTHOR_EMAILS" ] || refuse "分支 $CURRENT_BRANCH 上没有任何提交，没有东西可 ship"
  IDENTITY_EMAIL="$(git config user.email | tr '[:upper:]' '[:lower:]')"
  [ -n "$IDENTITY_EMAIL" ] || refuse "当前 git 身份没有配置 user.email，无法核对提交作者"
  FOREIGN_EMAILS="$(printf '%s\n' "$AUTHOR_EMAILS" | sort -u | grep -vxF "$IDENTITY_EMAIL" || true)"
  if [ -n "$FOREIGN_EMAILS" ]; then
    echo "❌ 存在与当前 git 身份邮箱（${IDENTITY_EMAIL}）不符的提交，先修正再 ship：" >&2
    git log "$BASE_REF..HEAD" --format='  %an <%ae>' 2>/dev/null | sort -u >&2 || true
    exit 1
  fi

  # 4) 高风类别路径：涉及数据库 / Edge Function / CI 的 PR 不允许脚本自动合并
  RISKY_FILES="$(git diff --name-only "$BASE_REF..HEAD" 2>/dev/null | grep -E '^(supabase/|\.github/)' || true)"

  # 5) [skip ci] 提示：Actions 不会跑，阶段二会因「无检查」拒绝。
  #    先取变量再 grep：管道里 git log 失败（如无提交的 orphan 分支）会在
  #    pipefail 下直接杀死脚本，grep 放进 if 条件则失败安全。
  LAST_MSG="$(git log -1 --format=%B 2>/dev/null || true)"
  if printf '%s' "$LAST_MSG" | grep -qiE '\[(skip ci|ci skip)\]'; then
    echo "⚠️  最新 commit 含 [skip ci]，GitHub Actions 不会运行任何检查，阶段二将拒绝合并" >&2
  fi

else
  # cleanup 阶段豁免上面全部守卫（原因见文件头注释），熔断由 stage_cleanup 内部承担。
  RISKY_FILES=""
fi

# ---------------- 阶段一 · 提 PR ----------------

stage_pr() {
  if [ -n "$RISKY_FILES" ]; then
    echo "⚠️  本次改动涉及高风类别路径，阶段二将拒绝自动合并、需人工处理：" >&2
    while IFS= read -r f; do echo "    $f" >&2; done <<< "$RISKY_FILES"
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] 守卫全部通过，将执行：push 分支 $CURRENT_BRANCH -> 建/复用 PR -> 盯 CI 并汇报"
    return 0
  fi

  echo "🚀 [1/3] 推送分支: $CURRENT_BRANCH"
  git push -u origin "$CURRENT_BRANCH"

  echo "📝 [2/3] 创建/复用 PR"
  pr_url
  if [ -z "$PR_URL" ]; then
    PR_URL="$(gh pr create --fill)"
  fi
  echo "🔗 PR 地址: $PR_URL"

  echo "⏳ [3/3] 等待 GitHub Actions 检查注册…"
  registered=false
  for _ in {1..15}; do
    if [ -n "$(gh pr checks --json state -q '.[].state' 2>/dev/null)" ]; then
      registered=true
      break
    fi
    sleep 2
  done
  if [ "$registered" = false ]; then
    echo "🚨 30 秒内 PR 上没有任何检查注册（可能是 [skip ci] 或 workflow 未触发）。" >&2
    echo "   不视作全绿。现场完整保留在: $CURRENT_WORKTREE" >&2
    exit 1
  fi

  if ! gh pr checks --watch; then
    echo "" >&2
    echo "🚨 CI 未通过！绝不合并、绝不删除。现场完整保留在: $CURRENT_WORKTREE" >&2
    echo "📋 失败日志摘要（最后 40 行）：" >&2
    RUN_ID="$(gh run list --branch "$CURRENT_BRANCH" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
    [ -z "$RUN_ID" ] || gh run view "$RUN_ID" --log-failed 2>/dev/null | tail -n 40 || true
    exit 1
  fi

  echo "✅ 云端 CI 全部通过。PR 已就绪，等你确认后再执行: bash scripts/ci/ship-pr.sh merge"
}

# ---------------- 阶段二 · 合并 ----------------

stage_merge() {
  [ -z "$RISKY_FILES" ] || refuse "改动涉及高风类别路径（supabase/ 或 .github/），脚本拒绝自动合并，请人工在 GitHub 上处理"
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] 将执行：复核检查（要求至少 1 个且全绿）-> squash merge（不删分支）-> ff-only 对齐 main"
    return 0
  fi

  pr_url
  [ -n "$PR_URL" ] || refuse "当前分支没有 PR，先执行: bash scripts/ci/ship-pr.sh"
  [ "$(gh pr view --json state -q .state)" = "OPEN" ] || refuse "PR 不是 OPEN 状态，无法合并"

  echo "🔍 [1/3] 复核检查状态（无检查 = 拒绝）…"
  states="$(gh pr checks --json state -q '.[].state' 2>/dev/null || true)"
  [ -n "$states" ] || refuse "PR 上没有任何检查，拒绝合并（可能 [skip ci] 或 workflow 未触发）"
  bad_states="$(printf '%s\n' "$states" | grep -vxE 'SUCCESS|SKIPPED|NEUTRAL|COMPLETED' || true)"
  [ -z "$bad_states" ] || refuse "存在未通过的检查状态：$(printf '%s\n' "$bad_states" | sort -u | tr '\n' ' ')"
  # GitHub 异步计算 mergeable：刚 push / 建 PR 后可能短暂为 UNKNOWN，
  # 不能当"有冲突"直接拒绝——轮询等待；只有 CONFLICTING 才是明确的拒绝理由。
  mergeable=""
  for _ in {1..10}; do
    mergeable="$(gh pr view --json mergeable -q .mergeable 2>/dev/null || true)"
    if [ "$mergeable" = "MERGEABLE" ] || [ "$mergeable" = "CONFLICTING" ]; then
      break
    fi
    sleep 2
  done
  if [ "$mergeable" = "CONFLICTING" ]; then
    refuse "PR 有冲突（CONFLICTING），无法合并"
  fi
  [ "$mergeable" = "MERGEABLE" ] || refuse "PR 合并状态未知（GitHub 尚未计算完成），请稍后重跑: bash scripts/ci/ship-pr.sh merge"

  echo "🔀 [2/3] Squash Merge（不删分支——远端与本地分支统一由阶段三清理）"
  PR_NUM="$(gh pr view --json number -q .number)"
  gh pr merge --squash

  echo "🔄 [3/3] 对齐主仓库 main（ff-only，禁止 reset --hard）"
  cd "$MAIN_REPO"
  git fetch origin main
  git checkout main 2>/dev/null || refuse "主仓库无法切到 main（可能有未提交改动），请人工处理"
  git merge --ff-only origin/main || refuse "本地 main 与远端分叉，脚本停止（不要 reset --hard）。处理方式见主仓库维护笔记后手动对齐"

  echo "🎉 PR #$PR_NUM 已合并，仓库已停在 main。确认关闭 Xcode 后清理现场:"
  echo "   bash scripts/ci/ship-pr.sh cleanup $PR_NUM"
}

# ---------------- 阶段三 · 清理 ----------------

stage_cleanup() {
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] 将执行：确认 PR 为 MERGED -> 删远端分支 -> 移除 worktree / 删本地分支（分支名以 PR 为准）"
    return 0
  fi

  # 合并后仓库已停在 main，分支名不能依赖当前 checkout，一律从 PR 解析。
  PR_NUM="${2:-}"
  if [ -z "$PR_NUM" ]; then
    # 合并后 PR 已关闭，gh pr view 按分支默认只找 open 的，须用 --state merged 按 head 找。
    # 若当前已在 main（阶段二收尾的常态），无法按分支推断，必须显式给 PR 号。
    [ "$CURRENT_BRANCH" != "main" ] || refuse "当前已在 main，无法按分支推断 PR，请带 PR 号: bash scripts/ci/ship-pr.sh cleanup <PR号>（阶段二收尾提示里有）"
    PR_NUM="$(gh pr list --state merged --head "$CURRENT_BRANCH" --json number -q '.[0].number' 2>/dev/null || true)"
  fi
  [ -n "$PR_NUM" ] || refuse "找不到当前分支对应的已合并 PR，请手动指定: bash scripts/ci/ship-pr.sh cleanup <PR号>"
  [ "$(gh pr view "$PR_NUM" --json state -q .state)" = "MERGED" ] || refuse "PR #$PR_NUM 状态不是 MERGED，拒绝清理"

  BRANCH_NAME="$(gh pr view "$PR_NUM" --json headRefName -q .headRefName)"
  [ -n "$BRANCH_NAME" ] || refuse "无法从 PR #$PR_NUM 解析 head 分支名，拒绝清理"

  # 当前位置核对：既不在 main、也不在 PR 自己的分支上 -> 拒绝（防止删错别的现场）
  if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
    refuse "当前分支 $CURRENT_BRANCH 与 PR #$PR_NUM 的 head 分支 $BRANCH_NAME 不一致，请在该分支的 worktree 里执行，或切到 main 后带 PR 号执行"
  fi

  # 1) 删远端分支。merge 时若仓库开了自动删分支设置，它可能已不存在——先查后删。
  if git ls-remote --exit-code origin "refs/heads/$BRANCH_NAME" >/dev/null 2>&1; then
    echo "🗑 [1/2] 删除远端分支: $BRANCH_NAME"
    git push origin --delete "$BRANCH_NAME"
  else
    echo "ℹ️ [1/2] 远端分支 $BRANCH_NAME 已不存在（已由合并或仓库设置清理）"
  fi

  # 2) 移除 worktree / 删本地分支
  if [ "$CURRENT_WORKTREE" != "$MAIN_REPO" ]; then
    echo "⚠️  即将移除 worktree: $CURRENT_WORKTREE"
    echo "    请确认 Xcode 已关闭该工程、没有其他会话正在该目录工作。"
    cd "$MAIN_REPO"
    # 不用 --force：目录里有未跟踪/修改文件时 git 会拒绝删除、保留现场。
    # 注意：删除成功即意味着脚本文件本体被删（worktree 里的副本），剩余步骤必须收在
    # 同一条复合命令里——bash 是整行读入解析后才执行的，分多行会中途读不到文件报错。
    { git worktree remove "$CURRENT_WORKTREE" || refuse "worktree 删除被 git 拒绝（目录含未跟踪/修改文件或被占用）。现场保留，人工检查后再删"; git branch -D "$BRANCH_NAME"; echo "🎉 清理完成：远端分支已删，worktree 与本地分支已移除，主仓库停在 main"; }
  else
    cd "$MAIN_REPO"
    if [ "$CURRENT_BRANCH" != "main" ]; then
      git checkout main 2>/dev/null || refuse "主仓库无法切到 main（可能有未提交改动），请人工处理"
    fi
    # 分支可能正被某个 worktree 占用（在 main 上执行时本脚本的 CURRENT_WORKTREE
    # 就是主仓库，拿不到那个 worktree），必须先按分支名找出并移除占用 worktree，
    # 否则删本地分支会被 git 拒绝。进程替换让循环留在当前 shell，refuse 才能真正终止。
    while IFS= read -r wt; do
      [ -n "$wt" ] || continue
      echo "⚠️  即将移除 worktree: $wt"
      echo "    请确认 Xcode 已关闭该工程、没有其他会话正在该目录工作。"
      git worktree remove "$wt" || refuse "worktree 删除被 git 拒绝（目录含未跟踪/修改文件或被占用）。现场保留，人工检查后再删"
    done < <(git worktree list --porcelain | awk -v b="refs/heads/$BRANCH_NAME" '
      /^worktree / { p = substr($0, 10) }
      /^branch / && $2 == b { print p }
    ')
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
      git branch -D "$BRANCH_NAME"
      echo "🎉 清理完成：远端与本地分支已删除，占用 worktree（如有）已移除，主仓库停在 main"
    else
      echo "🎉 清理完成：远端分支已删除，本地分支 $BRANCH_NAME 已不存在（合并时已删除），主仓库停在 main"
    fi
  fi
}

# ---------------- 执行 ----------------

case "$ACTION" in
  pr) stage_pr ;;
  merge) stage_merge ;;
  cleanup) stage_cleanup "$@" ;;
esac
