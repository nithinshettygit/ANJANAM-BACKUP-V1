# Build a release Android artifact with Supabase (and optional Razorpay) dart-defines.
# Without defines, AppEnv.fromEnvironment() fails and the app will not load.
#
# Prerequisites: Flutter SDK, tool\web_build.env (copy from tool\web_build.env.example).
#
# Usage:
#   .\scripts\build_android_release.ps1
#   .\scripts\build_android_release.ps1 -SplitPerAbi
#   .\scripts\build_android_release.ps1 -Bundle
param(
  [switch] $SplitPerAbi,
  [switch] $Bundle
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$KeyProps = Join-Path $Root "android\key.properties"
if (-not (Test-Path $KeyProps)) {
  throw "Missing android\key.properties. Copy from android\key.properties.example and fill real signing values."
}

$GoogleServices = Join-Path $Root "android\app\google-services.json"
if (-not (Test-Path $GoogleServices)) {
  throw "Missing android\app\google-services.json. Download from Firebase Console and place it there."
}

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
    throw "Missing $name. Set it in tool\web_build.env (see tool\web_build.env.example) or the environment."
  }
}

$supabaseUrl = [Environment]::GetEnvironmentVariable("SUPABASE_URL")
$supabaseKey = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY")
$functionsBase = [Environment]::GetEnvironmentVariable("SUPABASE_FUNCTIONS_BASE_URL")
$rzpKeyId = [Environment]::GetEnvironmentVariable("RAZORPAY_KEY_ID")

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseKey"
)
if (-not [string]::IsNullOrWhiteSpace($functionsBase)) {
  $defines += "--dart-define=SUPABASE_FUNCTIONS_BASE_URL=$functionsBase"
}
if (-not [string]::IsNullOrWhiteSpace($rzpKeyId)) {
  if ($rzpKeyId -notlike "rzp_live_*") {
    throw "RAZORPAY_KEY_ID must be a live key (rzp_live_...) for release builds."
  }
  $defines += "--dart-define=RAZORPAY_KEY_ID=$rzpKeyId"
}

$buildTarget = if ($Bundle) { "appbundle" } else { "apk" }
$buildArgs = @("build", $buildTarget, "--release") + $defines
if ($SplitPerAbi -and -not $Bundle) {
  $buildArgs += "--split-per-abi"
}

Write-Host "flutter $($buildArgs -join ' ')"
& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Bundle) {
  Write-Host "Output: $(Join-Path $Root 'build\app\outputs\bundle\release')"
} else {
  Write-Host "Output: $(Join-Path $Root 'build\app\outputs\flutter-apk')"
}
