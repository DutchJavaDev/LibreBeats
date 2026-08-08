#!/usr/bin/env bash
# Deploys the linked project (or the ref given as first argument): migrations, config,
# menu function. Needs a logged in cli. SUPABASE_DB_PUSH_BIN can point db push at
# another supabase binary, see the version note in the README.
set -euo pipefail
cd "$(dirname "$0")"

ref_args=()
if [[ $# -ge 1 ]]; then
  ref_args=(--project-ref "$1")
fi

db_push_bin="${SUPABASE_DB_PUSH_BIN:-supabase}"

echo '==> db push (migrations)'
"$db_push_bin" db push --yes ${ref_args[@]+"${ref_args[@]}"}

echo '==> config push (exposed schemas, auth)'
supabase config push --yes ${ref_args[@]+"${ref_args[@]}"}

echo '==> functions deploy: menu'
supabase functions deploy menu ${ref_args[@]+"${ref_args[@]}"}

echo 'Deploy finished.'
