#!/usr/bin/env bash
set -euo pipefail

# The suite uses dependency injection and test doubles. Passing the directory
# lets Deno discover every committed *_test file recursively, including .mjs
# tests, so a new test cannot be silently omitted from CI.
deno test --allow-env --allow-net supabase/functions
