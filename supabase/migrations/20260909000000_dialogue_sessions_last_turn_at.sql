-- 刀 2 · Tab2 话题卡 1.0：dialogue_sessions.last_turn_at（方案 B）
-- 把「最后一次用户开口」物化到 sessions，供 get_tab2_home 的 last_talked_at
-- 走 idx_dialogue_sessions_user_created 读取，避免每次进 Tab2 都全用户扫描
-- dialogue_turns（全系统写入量最大的表；其单列 user_id 索引的建表注释写明
-- 用途是「数据审计 / 隐私删除用」，不是热路径索引）。
-- 口径：最后一次对话 = 最后一次用户开口（role='user'）。
-- 写入方：supabase/functions/dialogue/index.ts 的 handleTurn，写用户轮次时顺手更新。
-- 不用 ended_at：该列全仓无任何写入方（20260801000000 建表即存在但从未接线）。
-- 存量测试数据不回填，last_turn_at 从 null 起步（表现为 Never talked，可接受）。

ALTER TABLE IF EXISTS dialogue_sessions
  ADD COLUMN IF NOT EXISTS last_turn_at timestamptz;

COMMENT ON COLUMN dialogue_sessions.last_turn_at IS
  '最后一次用户开口时间（role=''user'' 轮次），由 dialogue/index.ts handleTurn 更新；NULL = 从未开口';
