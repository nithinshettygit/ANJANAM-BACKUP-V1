# Build a release APK with Supabase (and optional Razorpay) dart-defines.
# Without defines, AppEnv.fromEnvironment() fails and the app will not load.
#
# Prerequisites: Flutter SDK, tool\web_build.env (copy from tool\web_build.env.example).
#
# Usage:
#   .\scripts\build_android_release.ps1
#   .\scripts\build_android_release.ps1 -SplitPerAbi
param(
  [switch] $SplitPerAbi
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
    throw "Missing $name. Set it in tool\web_build.env (see tool\web_build.env.example) or the environment."
  }
}

$supabaseUrl = [Environment]::GetEnvironmentVariable("SUPABASE_URL")
$supabaseKey = [Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY")
$functionsBase = [Environment]::GetEnvironmentVariable("SUPABASE_FUNCTIONS_BASE_URL")
$rzpTest = [Environment]::GetEnvironmentVariable("RAZORPAY_TEST_KEY")
$rzpKeyId = [Environment]::GetEnvironmentVariable("RAZORPAY_KEY_ID")

$defines = @(
  "--dart-define=SUPABASE_URL=$supabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$supabaseKey"
)
if (-not [string]::IsNullOrWhiteSpace($functionsBase)) {
  $defines += "--dart-define=SUPABASE_FUNCTIONS_BASE_URL=$functionsBase"
}
if (-not [string]::IsNullOrWhiteSpace($rzpKeyId)) {
  $defines += "--dart-define=RAZORPAY_KEY_ID=$rzpKeyId"
}
elseif (-not [string]::IsNullOrWhiteSpace($rzpTest)) {
  $defines += "--dart-define=RAZORPAY_TEST_KEY=$rzpTest"
}

$apkArgs = @("build", "apk", "--release") + $defines
if ($SplitPerAbi) {
  $apkArgs += "--split-per-abi"
}

Write-Host "flutter $($apkArgs -join ' ')"
& flutter @apkArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Output: $(Join-Path $Root 'build\app\outputs\flutter-apk')"
