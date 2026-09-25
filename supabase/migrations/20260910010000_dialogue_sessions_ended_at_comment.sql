-- 刀 5 收尾 · dialogue_sessions.ended_at 现状标注（PM 拍板 2026-09-10）
-- 诊断：该列 20260801000000 建表即存在，但全仓无任何写入方——
-- dialogue/index.ts 从不写它，契约 §2.4「写 ended_at + end_reason」
-- 是与实现不符的旧承诺。刀 2「最后一次开口」口径已用 last_turn_at
-- （20260909000000）绕开本列，不再依赖它。
-- PM 拍板：保留该列作未来预留（总结卡幂等与 resume 判定），
-- 但注释必须写明「当前无写入方」，防止后来者误信该列有值。

COMMENT ON COLUMN dialogue_sessions.ended_at IS
  '当前无写入方（全仓无任何代码写该列，契约 §2.4 的写入承诺未兑现）。NULL = 进行中。未来预留：总结卡幂等与 resume 判定';
