# Reverts the whole librebeats deployment without supabase login: schema, pgmq, buckets,
# listener user and the migration history rows. Destructive, there is no undo.
#   SUPABASE_DB_URL       required, connection string of the target
#   SUPABASE_ACCESS_TOKEN optional, together with SUPABASE_PROJECT_REF also deletes the
#                         menu function and resets the exposed api schemas
# Uses local psql when available, otherwise a postgres docker image. Local stack:
# supabase db reset does the same thing.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$env:SUPABASE_DB_URL = ''
$env:SUPABASE_ACCESS_TOKEN = ''
$env:SUPABASE_PROJECT_REF = ''

if (-not $env:SUPABASE_DB_URL) {
  Write-Error 'SUPABASE_DB_URL is required'
}

# history rows, versions taken from the filenames so new migrations are covered
$versions = (Get-ChildItem supabase\migrations\*.sql | ForEach-Object { "'" + ($_.Name -split '_')[0] + "'" }) -join ','
$tracking = "do `$`$ begin if to_regclass('supabase_migrations.schema_migrations') is not null then delete from supabase_migrations.schema_migrations where version in ($versions); end if; end `$`$;"

Write-Host '==> reverting database objects'
if (Get-Command psql -ErrorAction SilentlyContinue) {
  psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -f revert.sql
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -c $tracking
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
else {
  Get-Content revert.sql -Raw | docker run --rm -i postgres:17-alpine psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -f -
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  docker run --rm postgres:17-alpine psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -c $tracking
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($env:SUPABASE_ACCESS_TOKEN -and $env:SUPABASE_PROJECT_REF) {
  Write-Host '==> deleting menu function'
  supabase functions delete menu --project-ref $env:SUPABASE_PROJECT_REF
  if ($LASTEXITCODE -ne 0) { Write-Host 'could not delete the function (already gone?), continuing' }

  Write-Host '==> resetting exposed api schemas'
  Invoke-RestMethod -Method Patch `
    -Uri "https://api.supabase.com/v1/projects/$($env:SUPABASE_PROJECT_REF)/postgrest" `
    -Headers @{ Authorization = "Bearer $($env:SUPABASE_ACCESS_TOKEN)" } `
    -ContentType 'application/json' -Body '{"db_schema":"public, graphql_public"}' | Out-Null
}
else {
  Write-Host 'SUPABASE_ACCESS_TOKEN / SUPABASE_PROJECT_REF not set, skipped the function delete and schema reset.'
}

Write-Host 'Revert finished.'
