CREATE OR REPLACE FUNCTION public.increment_session_count()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.profiles
  SET session_count = session_count + 1,
      updated_at    = now()
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_session_count() TO authenticated;
