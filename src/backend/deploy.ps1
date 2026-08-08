# Deploys the linked project (or -ProjectRef): migrations, config, menu function.
# Needs a logged in cli. SUPABASE_DB_PUSH_BIN can point db push at another supabase.exe,
# see the version note in the README.
param(
  [string]$ProjectRef
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$refArgs = @()
if ($ProjectRef) { $refArgs = @('--project-ref', $ProjectRef) }

$dbPushBin = if ($env:SUPABASE_DB_PUSH_BIN) { $env:SUPABASE_DB_PUSH_BIN } else { 'supabase' }

Write-Host '==> db push (migrations)'
& $dbPushBin db push --yes @refArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '==> config push (exposed schemas, auth)'
supabase config push --yes @refArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '==> functions deploy: menu'
supabase functions deploy menu @refArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Deploy finished.'
