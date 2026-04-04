Set-Location $PSScriptRoot\..
flutter build web --release
firebase deploy --only hosting
