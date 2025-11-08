Param()
$ErrorActionPreference = 'Stop'

Write-Host "Running flutter pub get..." -ForegroundColor Cyan
flutter pub get

Write-Host "Generating launcher icons for all platforms..." -ForegroundColor Cyan
flutter pub run flutter_launcher_icons

Write-Host "Done. If you see errors about missing icon/icon.png, add a 1024x1024 PNG there and rerun this script." -ForegroundColor Green
