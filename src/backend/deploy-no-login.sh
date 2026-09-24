#!/usr/bin/env bash
# Deploy without supabase login.
#   SUPABASE_DB_URL       required, connection string of the target (url-encode the password)
#   SUPABASE_ACCESS_TOKEN optional, together with SUPABASE_PROJECT_REF also pushes config
#                         and deploys the menu function
# With only the db url this just applies migrations, which is all the cli can do against
# the self hosted stack anyway (functions there are copied files, see copy.sh).
set -euo pipefail
cd "$(dirname "$0")"

: "${SUPABASE_DB_URL:?SUPABASE_DB_URL is required}"

echo '==> db push (migrations)'
supabase db push --yes --db-url "$SUPABASE_DB_URL"

if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" && -n "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo '==> config push (exposed schemas, auth)'
  supabase config push --yes --project-ref "$SUPABASE_PROJECT_REF"

  echo '==> functions deploy: menu'
  supabase functions deploy menu --project-ref "$SUPABASE_PROJECT_REF"
else
  echo 'SUPABASE_ACCESS_TOKEN / SUPABASE_PROJECT_REF not set, skipped config push and functions deploy.'
fi

echo 'Deploy finished.'
