-- 用户反馈表（App 内 Feedback & Report，方案 C）
-- 安全：Edge Function 以 service_role 写入并回填 user_id；RLS 开启作纵深防御，
-- 不建任何面向 anon/authenticated 的策略，因此只有 service_role 能读写
-- （你在 Supabase 后台 Table Editor 查看反馈）。

create table if not exists public.feedback (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  category      text not null check (category in ('bug', 'suggestion', 'other')),
  body          text not null check (char_length(body) between 1 and 1000),
  contact_email text,
  app_version   text,
  device_info   text,
  created_at    timestamptz not null default now()
);

create index if not exists feedback_user_id_idx    on public.feedback (user_id);
create index if not exists feedback_created_at_idx  on public.feedback (created_at desc);

alter table public.feedback enable row level security;
-- 刻意不建 permissive policy：仅 service_role（Edge Function）可读写。
-- user_id 对 auth.users 带 on delete cascade —— 删除账号时反馈随之清除，
-- 无需在 delete-account 里显式处理。
