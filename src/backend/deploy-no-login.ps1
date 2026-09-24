# Deploy without supabase login.
#   SUPABASE_DB_URL       required, connection string of the target (url-encode the password)
#   SUPABASE_ACCESS_TOKEN optional, together with SUPABASE_PROJECT_REF also pushes config
#                         and deploys the menu function
# With only the db url this just applies migrations, which is all the cli can do against
# the self hosted stack anyway (functions there are copied files, see copy.sh).
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not $env:SUPABASE_DB_URL) {
  Write-Error 'SUPABASE_DB_URL is required'
}

Write-Host '==> db push (migrations)'
supabase db push --yes --db-url $env:SUPABASE_DB_URL
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($env:SUPABASE_ACCESS_TOKEN -and $env:SUPABASE_PROJECT_REF) {
  Write-Host '==> config push (exposed schemas, auth)'
  supabase config push --yes --project-ref $env:SUPABASE_PROJECT_REF
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host '==> functions deploy: menu'
  supabase functions deploy menu --project-ref $env:SUPABASE_PROJECT_REF
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
else {
  Write-Host 'SUPABASE_ACCESS_TOKEN / SUPABASE_PROJECT_REF not set, skipped config push and functions deploy.'
}

Write-Host 'Deploy finished.'
