# Reverts the whole librebeats deployment from the linked project (or -ProjectRef):
# schema, pgmq, buckets, listener user, migration history and the menu function.
# Destructive, there is no undo.
# Needs a logged in cli. SUPABASE_DB_URL is still required, the cli cannot run sql
# over a login session. With SUPABASE_ACCESS_TOKEN set the exposed api schemas are
# reset as well. Local stack: supabase db reset does the same thing.
param(
  [string]$ProjectRef
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not $env:SUPABASE_DB_URL) {
  Write-Error 'SUPABASE_DB_URL is required for the sql teardown'
}
if (-not $ProjectRef -and (Test-Path supabase\.temp\project-ref)) {
  $ProjectRef = (Get-Content supabase\.temp\project-ref -Raw).Trim()
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

if ($ProjectRef) {
  Write-Host '==> deleting menu function'
  supabase functions delete menu --project-ref $ProjectRef
  if ($LASTEXITCODE -ne 0) { Write-Host 'could not delete the function (already gone?), continuing' }

  if ($env:SUPABASE_ACCESS_TOKEN) {
    Write-Host '==> resetting exposed api schemas'
    Invoke-RestMethod -Method Patch `
      -Uri "https://api.supabase.com/v1/projects/$ProjectRef/postgrest" `
      -Headers @{ Authorization = "Bearer $($env:SUPABASE_ACCESS_TOKEN)" } `
      -ContentType 'application/json' -Body '{"db_schema":"public, graphql_public"}' | Out-Null
  }
}
else {
  Write-Host 'no linked project and no -ProjectRef, skipped the function delete'
}

Write-Host 'Revert finished.'
