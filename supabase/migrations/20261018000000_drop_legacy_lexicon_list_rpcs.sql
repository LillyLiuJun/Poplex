-- Drop the three legacy lexicon-list RPCs that survive only on the production
-- database (see 20260831131306_harden_legacy_rpc_privileges.sql). They backed
-- the abandoned Tab2 word-list design (PRD v2 Slice 5) through the Edge
-- Functions get-lexicon and exclude-lexicon-entry, which were deleted from
-- production on 2026-10-18 and never existed in this repository.
--
-- Before dropping, production was checked for callers: EXECUTE is held only by
-- postgres and service_role; no function, view or trigger references them; and
-- none of the 15 deployed Edge Functions mentions them. A clean database never
-- creates them, so IF EXISTS keeps a fresh migration replay a no-op.
DROP FUNCTION IF EXISTS public.get_lexicon_entries_tab2(uuid, integer);
DROP FUNCTION IF EXISTS public.exclude_lexicon_entry(uuid, uuid);
DROP FUNCTION IF EXISTS public.restore_lexicon_entry(uuid, uuid);
