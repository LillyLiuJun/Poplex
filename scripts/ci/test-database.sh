#!/usr/bin/env bash
set -euo pipefail

# `supabase db reset --local` erases and recreates the selected local database.
# GitHub Actions always sets CI=true and runs on an ephemeral runner. A local
# invocation requires an explicit acknowledgement to avoid resetting a developer's
# working database by accident.
if [[ "${CI:-}" != "true" && "${ALLOW_LOCAL_SUPABASE_RESET:-}" != "1" ]]; then
  echo "Refusing to reset a local Supabase database. Re-run with ALLOW_LOCAL_SUPABASE_RESET=1."
  exit 2
fi

# config.toml is deliberately untracked so each worktree can pin its own local
# ports without dirtying a tracked file. Fresh checkouts (including the CI
# runner) get the CI defaults from the committed example.
if [ ! -f supabase/config.toml ] && [ -f supabase/config.toml.example ]; then
  cp supabase/config.toml.example supabase/config.toml
fi

trap 'supabase stop' EXIT

supabase start --exclude edge-runtime,gotrue,imgproxy,kong,logflare,mailpit,postgres-meta,postgrest,realtime,storage-api,studio,supavisor,vector

supabase db reset --local --no-seed
supabase test db --local supabase/tests
supabase db lint --local --level warning --fail-on warning
