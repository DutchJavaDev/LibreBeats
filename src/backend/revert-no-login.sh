#!/usr/bin/env bash
# Reverts the whole librebeats deployment without supabase login: schema, pgmq, buckets,
# listener user and the migration history rows. Destructive, there is no undo.
#   SUPABASE_DB_URL       required, connection string of the target
#   SUPABASE_ACCESS_TOKEN optional, together with SUPABASE_PROJECT_REF also deletes the
#                         menu function and resets the exposed api schemas
# Uses local psql when available, otherwise a postgres docker image. Local stack:
# supabase db reset does the same thing.
set -euo pipefail
cd "$(dirname "$0")"

SUPABASE_DB_URL = ''
SUPABASE_ACCESS_TOKEN = ''
SUPABASE_PROJECT_REF = ''

: "${SUPABASE_DB_URL:?SUPABASE_DB_URL is required}"

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

if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" && -n "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo '==> deleting menu function'
  supabase functions delete menu --project-ref "$SUPABASE_PROJECT_REF" \
    || echo 'could not delete the function (already gone?), continuing'

  echo '==> resetting exposed api schemas'
  curl -sf -X PATCH "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/postgrest" \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"db_schema":"public, graphql_public"}' > /dev/null
else
  echo 'SUPABASE_ACCESS_TOKEN / SUPABASE_PROJECT_REF not set, skipped the function delete and schema reset.'
fi

echo 'Revert finished.'
