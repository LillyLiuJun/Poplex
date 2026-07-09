-- 允许用户写入自己的 profile 行（upsert 自愈需要 INSERT 权限）。
-- 触发器负责新用户首次建行；此策略兜底旧账号或触发器遗漏时客户端补建。
CREATE POLICY "insert_own_profile"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);
