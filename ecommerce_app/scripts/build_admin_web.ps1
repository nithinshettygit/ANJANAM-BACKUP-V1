# Build the Flutter web bundle for Firebase Hosting (admin + full router; use /admin URLs).
# Prerequisites: Flutter SDK, dart defines in tool/web_build.env or current environment.
#
# Supabase: add your Hosting URL under Authentication > URL Configuration (Site URL / Redirect URLs).
#
# Usage:
#   .\scripts\build_admin_web.ps1
#   .\scripts\build_admin_web.ps1 -Deploy
#   .\scripts\build_admin_web.ps1 -BaseHref "/admin-app/"
param(
  [string] $BaseHref = "/",
  [string] $ProjectId = "anjanam-app",
  [switch] $Deploy
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$EnvFile = Join-Path $Root "tool\web_build.env"
if (Test-Path $EnvFile) {
  Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $pair = $_ -split '=', 2
    if ($pair.Length -eq 2) {
      $key = $pair[0].Trim()
      $val = $pair[1].Trim()
      if ($key) { Set-Item -Path "Env:$key" -Value $val }
    }
  }
}

foreach ($name in @("SUPABASE_URL", "SUPABASE_ANON_KEY")) {
  $v = [Environment]::GetEnvironmentVariable($name)
  if ([string]::IsNullOrWhiteSpace($v)) {
    throw "Missing $name. Set it in the environment or in tool/web_build.env (see tool/web_build.env.example)."
  }
}

$supabaseUrl = [Environment]::GetEnvironmentVariable("SUPABASE_URL")
$supabaseKey = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY")
$functionsBase = [Environment]::GetEnvironmentVariable("SUPABASE_FUNCTIONS_BASE_URL")
$rzp = [Environment]::GetEnvironmentVariable("RAZORPAY_KEY_ID")
$authRedirect = [Environment]::GetEnvironmentVariable("SUPABASE_AUTH_REDIRECT_URL")
$passwordResetRedirect = [Environment]::GetEnvironmentVariable("SUPABASE_PASSWORD_RESET_REDIRECT_URL")

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseKey"
)
if (-not [string]::IsNullOrWhiteSpace($functionsBase)) {
  $defines += "--dart-define=SUPABASE_FUNCTIONS_BASE_URL=$functionsBase"
}
if (-not [string]::IsNullOrWhiteSpace($rzp)) {
  $defines += "--dart-define=RAZORPAY_KEY_ID=$rzp"
}
if (-not [string]::IsNullOrWhiteSpace($authRedirect)) {
  $defines += "--dart-define=SUPABASE_AUTH_REDIRECT_URL=$authRedirect"
}
if (-not [string]::IsNullOrWhiteSpace($passwordResetRedirect)) {
  $defines += "--dart-define=SUPABASE_PASSWORD_RESET_REDIRECT_URL=$passwordResetRedirect"
}

# --web-renderer html: default CanvasKit loads from Google CDN; if that is blocked, the site stays white.
# --pwa-strategy none: avoids a service worker caching an old broken bundle after you fix the build.
Write-Host "flutter build web --release --base-href=$BaseHref --web-renderer html --pwa-strategy none $($defines -join ' ')"
& flutter build web --release --base-href=$BaseHref --web-renderer html --pwa-strategy none @defines
if ($LASTEXITCODE -ne 0) {
  Write-Host "Retrying without --web-renderer / --pwa-strategy (older Flutter)..." -ForegroundColor Yellow
  & flutter build web --release --base-href=$BaseHref @defines
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Syncing hosting extras (assetlinks, legal pages, optional app-config.json)..."
& dart run tool/ensure_well_known_for_hosting.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Deploy) {
  & firebase deploy --only hosting --project $ProjectId
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Output: $(Join-Path $Root 'build\web')"
