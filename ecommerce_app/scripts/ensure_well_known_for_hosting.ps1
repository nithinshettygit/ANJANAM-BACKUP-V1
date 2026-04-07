# Fallback if `dart run tool/ensure_well_known_for_hosting.dart` is not available.
# Prefer: `firebase deploy` (hosting.predeploy copies this file automatically).
$ErrorActionPreference = "Stop"
$appRoot = Split-Path $PSScriptRoot -Parent
$src = Join-Path $appRoot "web\.well-known\assetlinks.json"
$dstDir = Join-Path $appRoot "build\web\.well-known"
if (-not (Test-Path $src)) {
  Write-Error "Missing $src"
}
New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
Copy-Item -Force $src (Join-Path $dstDir "assetlinks.json")
Write-Host "OK: copied assetlinks.json -> build\web\.well-known\"
