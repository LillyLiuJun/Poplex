-- analytics_events is written only by the server-side log-event Edge Function.
-- Keep it inaccessible through the public Data API; service_role bypasses RLS.
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.analytics_events FROM PUBLIC, anon, authenticated;
GRANT INSERT ON TABLE public.analytics_events TO service_role;
