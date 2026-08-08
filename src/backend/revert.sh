#!/usr/bin/env bash
# Reverts the whole librebeats deployment from the linked project (or the ref given as
# first argument): schema, pgmq, buckets, listener user, migration history and the menu
# function. Destructive, there is no undo.
# Needs a logged in cli. SUPABASE_DB_URL is still required, the cli cannot run sql over
# a login session. With SUPABASE_ACCESS_TOKEN set the exposed api schemas are reset as
# well. Local stack: supabase db reset does the same thing.
set -euo pipefail
cd "$(dirname "$0")"

: "${SUPABASE_DB_URL:?SUPABASE_DB_URL is required for the sql teardown}"

ref="${1:-}"
if [[ -z "$ref" && -f supabase/.temp/project-ref ]]; then
  ref=$(<supabase/.temp/project-ref)
fi

# history rows, versions taken from the filenames so new migrations are covered
versions=''
for f in supabase/migrations/*.sql; do
  b=${f##*/}
  versions+="'${b%%_*}',"
done
versions=${versions%,}
tracking="do \$\$ begin if to_regclass('supabase_migrations.schema_migrations') is not null then delete from supabase_migrations.schema_migrations where version in ($versions); end if; end \$\$;"

echo '==> reverting database objects'
if command -v psql >/dev/null; then
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f revert.sql
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -c "$tracking"
else
  docker run --rm -i postgres:17-alpine psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f - < revert.sql
  docker run --rm postgres:17-alpine psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -c "$tracking"
fi

if [[ -n "$ref" ]]; then
  echo '==> deleting menu function'
  supabase functions delete menu --project-ref "$ref" \
    || echo 'could not delete the function (already gone?), continuing'

  if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
    echo '==> resetting exposed api schemas'
    curl -sf -X PATCH "https://api.supabase.com/v1/projects/$ref/postgrest" \
      -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
      -H 'Content-Type: application/json' \
      -d '{"db_schema":"public, graphql_public"}' > /dev/null
  fi
else
  echo 'no linked project and no ref argument, skipped the function delete'
fi

echo 'Revert finished.'
