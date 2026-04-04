# Encodes a Google service account JSON file to a single line for
# Supabase > Edge Functions > Secrets > GOOGLE_SERVICE_ACCOUNT_JSON_BASE64
#
# IMPORTANT: project_id inside the JSON must match Firebase android/app google-services.json
# (this app uses Firebase project "anjanam-app").
#
# Usage:
#   .\scripts\encode_fcm_service_account.ps1 -JsonPath "D:\path\to\anjanam-app-xxxxx.json"
# Then open the generated .base64.txt and paste its full contents into the Supabase secret.

param(
    [Parameter(Mandatory = $true)]
    [string]$JsonPath
)

if (-not (Test-Path -LiteralPath $JsonPath)) {
    Write-Error "File not found: $JsonPath"
    exit 1
}

$raw = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8
$parsed = $raw | ConvertFrom-Json
$pid = $parsed.project_id
Write-Host "project_id in file: $pid"
if ($pid -ne "anjanam-app") {
    Write-Warning "Expected project_id 'anjanam-app' for this ecommerce Android app. Wrong project = FCM will not reach devices."
}

$bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
$b64 = [Convert]::ToBase64String($bytes)
$out = [System.IO.Path]::ChangeExtension($JsonPath, ".base64.txt")
[System.IO.File]::WriteAllText($out, $b64, [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote: $out"
Write-Host "Paste the entire file contents into Supabase secret GOOGLE_SERVICE_ACCOUNT_JSON_BASE64, then redeploy send-notification if needed."
