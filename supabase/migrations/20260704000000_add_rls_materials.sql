-- Slice C (user_id isolation): enable RLS on materials table as defense-in-depth.
--
-- 为什么需要 RLS：
-- Edge Function 用 service role key 访问 DB，会绕过 RLS（这是设计如此）。
-- 但如果有人拿到 anonKey，直接用 PostgREST REST API 访问，RLS 会拦住——
-- 他只能看到 user_id = auth.uid() 的行，即自己的数据。
-- 这是在应用层过滤（Edge Function）之外的数据库层保险。
--
-- 已知前提：materials.user_id 已全部回填（不再有 null），且 auth.users 使用匿名登录。
-- anonymous 用户的 auth.uid() 会返回他们的匿名 UUID，策略对他们同样生效。

-- 1. 开启 RLS（开启后，没有匹配策略的请求默认拒绝）
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;

-- 2. SELECT：用户只能读到自己的素材
CREATE POLICY "users_select_own_materials"
  ON materials
  FOR SELECT
  USING (auth.uid() = user_id);

-- 3. INSERT：用户只能插入 user_id = 自己的行（防止伪造归属）
CREATE POLICY "users_insert_own_materials"
  ON materials
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 4. UPDATE：用户只能修改自己的素材（包括软删除的 deleted_at 字段）
CREATE POLICY "users_update_own_materials"
  ON materials
  FOR UPDATE
  USING (auth.uid() = user_id);

-- 5. DELETE：用户只能硬删自己的行（实际业务走软删除，这层是兜底）
CREATE POLICY "users_delete_own_materials"
  ON materials
  FOR DELETE
  USING (auth.uid() = user_id);
