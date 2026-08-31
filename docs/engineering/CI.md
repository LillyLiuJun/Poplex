# CI verification

This document is the source of truth for pull-request verification. The same
scripts are used locally and by `.github/workflows/ci.yml`; do not duplicate
their commands in agent instructions.

## Pull-request gate

Every pull request targeting `main` runs these checks in parallel:

| Check | Runner | What it verifies |
|---|---|---|
| `iOS tests` | macOS | Build, all unit tests, and the existing UI launch test (the non-functional Xcode template performance sample is skipped) |
| `Edge Function tests` | Ubuntu | Deno recursively discovers every committed `*_test` file under `supabase/functions/` |
| `Database tests` | Ubuntu | A fresh local Supabase database can replay every migration; pgTAP behavior tests, the database privilege contract, and lint pass |

The GitHub repository must require all three named checks before a PR can merge
to `main`. Require branches to be up to date before merging. Do not add
production secrets to this PR workflow.

`iOS tests` runs only when iOS-relevant paths change (the Swift sources, the
Xcode project, the iOS test script, or the workflow files) or on
`workflow_dispatch`. Backend-only PRs skip the macOS build and the check still
reports success, so required-check semantics are unchanged.

The table-level ACL contract lives in
`supabase/tests/ci_privilege_contract_test.sql`. When an Edge Function gains a
new direct table read or write using `service_role`, update that test and the
single CI privilege migration in the same PR. RLS is still required for every
client-accessible table; service_role bypasses RLS and is safe only after the
function has authenticated the caller and constrained the operation to that
caller’s data.

## Local verification

Run the relevant script after a slice is stable, then report the command and
result to the project owner:

```bash
bash scripts/ci/test-ios.sh
bash scripts/ci/test-edge-functions.sh
ALLOW_LOCAL_SUPABASE_RESET=1 bash scripts/ci/test-database.sh
```

`test-database.sh` resets the local Supabase database. It refuses to run
outside GitHub Actions unless `ALLOW_LOCAL_SUPABASE_RESET=1` is supplied.
It never uses `--linked`, so it cannot target the hosted production project.

`supabase/config.toml` is untracked and per-worktree, so each worktree can pin
its own local ports (e.g. when two local stacks run at once). `test-database.sh`
copies `supabase/config.toml.example` when the file is missing, which covers
fresh checkouts and the CI runner.

The iOS script resolves the preferred device to a UDID — duplicate device
names (e.g. a cloned simulator) cannot fail the build — and falls back to the
iPhone with the newest OS version when the preferred device is missing (hosted
runner images rotate their device sets). Set `IOS_SIMULATOR_DESTINATION` to
pin a specific device.

## Current UI-test scope

The shared iOS scheme includes the UI-test target, but its current tests only
cover launch/template behaviour. Add stable UI smoke tests for real critical
flows before creating a nightly UI-regression workflow. Until then, `iOS tests`
is a required PR check, not evidence of full UI regression coverage.

## Publishing boundary

This CI workflow only verifies PRs. It does not deploy Supabase changes, upload
TestFlight builds, or receive production credentials. A separate, manually
approved deployment workflow is required before any production release.
