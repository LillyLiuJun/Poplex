-- Generation quota data layer (生成次数限制 · 第 1 刀).
--
-- Two-layer limit model:
--   app_config.daily_generation_limit  — the global daily limit, one row.
--   profiles.daily_generation_limit    — a per-user override; NULL means
--     "follow the global value". The column is deliberately NULL-able with
--     no default: NULL (inherit) and a concrete number (individually set)
--     must stay distinguishable, so raising the global value never overwrites
--     a user who was individually relaxed, and revoking a special quota is
--     just setting the column back to NULL.
--
-- Counting only advances on successful commits; the consume step lands with
-- slice 2, inside the commit RPC's transaction. generation_usage is therefore
-- server-written: clients get a SELECT policy and nothing else, and the write
-- path goes through SECURITY DEFINER functions.

CREATE TABLE public.generation_usage (
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  usage_date  date NOT NULL,
  used_count  integer NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  updated_at  timestamptz,
  PRIMARY KEY (user_id, usage_date)
);

-- Future cleanup of historical rows (e.g. keep only the last N days) scans
-- by date.
CREATE INDEX idx_generation_usage_usage_date
  ON public.generation_usage (usage_date);

ALTER TABLE public.generation_usage ENABLE ROW LEVEL SECURITY;

-- Clients may read their own row (the usage sheet shows today's numbers) but
-- may never write: the counter is advanced only by the SECURITY DEFINER
-- consume path, so there is deliberately no INSERT/UPDATE policy.
CREATE POLICY "users_select_own_generation_usage"
  ON public.generation_usage
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Global quota configuration. Ops adjust the daily limit by updating this one
-- row; the effective-limit function reads it per call, so a change applies
-- immediately to every user without an individual override.
CREATE TABLE public.app_config (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL,
  updated_at  timestamptz
);

INSERT INTO public.app_config (key, value)
VALUES ('daily_generation_limit', '5');

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Readable by any signed-in user (the client shows the effective limit), but
-- nothing below grants write access: config edits are ops actions.
CREATE POLICY "users_select_app_config"
  ON public.app_config
  FOR SELECT
  TO authenticated
  USING (true);

-- Per-user override (see the model note above).
ALTER TABLE public.profiles
  ADD COLUMN daily_generation_limit integer;

-- profiles is client-writable (insert_own_profile self-healing upsert +
-- update_own_profile), and its table-level grants are required by the CI
-- privilege contract — but PostgreSQL column ACLs only ever ADD privileges
-- on top of a table-level grant and never subtract from it (a column-level
-- REVOKE here is a no-op, verified empirically: attacl stays empty and the
-- update still goes through). The override column is guarded by a trigger
-- instead: client writes to it are silently stripped, server roles pass
-- through untouched. Relaxing a user's quota is an ops action, never a
-- client action.
CREATE OR REPLACE FUNCTION public.guard_daily_generation_limit_override()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $func$
BEGIN
  IF current_user NOT IN ('postgres', 'service_role') THEN
    IF TG_OP = 'INSERT' THEN
      NEW.daily_generation_limit := NULL;
    ELSE
      NEW.daily_generation_limit := OLD.daily_generation_limit;
    END IF;
  END IF;
  RETURN NEW;
END;
$func$;

CREATE TRIGGER profiles_daily_generation_limit_guard
  BEFORE INSERT OR UPDATE OF daily_generation_limit
  ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_daily_generation_limit_override();

REVOKE ALL ON FUNCTION public.guard_daily_generation_limit_override()
  FROM PUBLIC, anon, authenticated, service_role;

-- Encode the exact table-level ACL for the two new tables so a fresh local
-- replay and the hosted platform (whose default privileges would otherwise
-- grant all to the API roles) behave identically. RLS stays the row-security
-- boundary; these are the minimum grants that let the policies be reached.
-- No API role may write either table: generation_usage advances only inside
-- SECURITY DEFINER functions (slice 2), app_config is ops-only.
REVOKE ALL ON TABLE public.generation_usage
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.generation_usage TO authenticated;

REVOKE ALL ON TABLE public.app_config
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.app_config TO authenticated;
