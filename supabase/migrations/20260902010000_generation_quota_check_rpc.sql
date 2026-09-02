-- Quota read RPCs (生成次数限制 · 第 1 刀). Two entries with different
-- permission models — deliberately not one shared function:
--
--   check_generation_quota(date)            — the client-facing read. Takes no
--     user_id (auth.uid() is resolved inside) so a signed-in user can never
--     ask about someone else's usage.
--   check_generation_quota_for_user(uuid, date) — the Edge Function entry.
--     Accepts an arbitrary user_id and is therefore EXECUTE-granted to
--     service_role only.
--
-- Both return (used_count, limit, allowed) where limit is the effective daily
-- limit after applying the profiles override.

CREATE OR REPLACE FUNCTION public.get_effective_daily_generation_limit(
  p_user_id uuid
)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    -- NULL override or missing profiles row → fall through to the global value.
    (SELECT p.daily_generation_limit
       FROM public.profiles p
      WHERE p.id = p_user_id),
    (SELECT c.value::integer
       FROM public.app_config c
      WHERE c.key = 'daily_generation_limit')
  );
$$;

-- Only service-role callers (Edge Functions) may resolve a named user's limit.
REVOKE ALL ON FUNCTION public.get_effective_daily_generation_limit(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_effective_daily_generation_limit(uuid)
  TO service_role;

CREATE OR REPLACE FUNCTION public.check_generation_quota(p_usage_date date)
RETURNS TABLE (used_count integer, "limit" integer, allowed boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    COALESCE(
      (SELECT u.used_count
         FROM public.generation_usage u
        WHERE u.user_id = auth.uid()
          AND u.usage_date = p_usage_date),
      0
    ) AS used_count,
    public.get_effective_daily_generation_limit(auth.uid()) AS "limit",
    COALESCE(
      (SELECT u.used_count
         FROM public.generation_usage u
        WHERE u.user_id = auth.uid()
          AND u.usage_date = p_usage_date),
      0
    ) < public.get_effective_daily_generation_limit(auth.uid()) AS allowed;
$$;

REVOKE ALL ON FUNCTION public.check_generation_quota(date)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_generation_quota(date)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.check_generation_quota_for_user(
  p_user_id uuid,
  p_usage_date date
)
RETURNS TABLE (used_count integer, "limit" integer, allowed boolean)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    COALESCE(
      (SELECT u.used_count
         FROM public.generation_usage u
        WHERE u.user_id = p_user_id
          AND u.usage_date = p_usage_date),
      0
    ) AS used_count,
    public.get_effective_daily_generation_limit(p_user_id) AS "limit",
    COALESCE(
      (SELECT u.used_count
         FROM public.generation_usage u
        WHERE u.user_id = p_user_id
          AND u.usage_date = p_usage_date),
      0
    ) < public.get_effective_daily_generation_limit(p_user_id) AS allowed;
$$;

REVOKE ALL ON FUNCTION public.check_generation_quota_for_user(uuid, date)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_generation_quota_for_user(uuid, date)
  TO service_role;
