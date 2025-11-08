# Copies icon/icon.ico to platform-specific locations if present.
Param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $root
$iconPath = Join-Path $projectRoot 'icon\icon.ico'

if (!(Test-Path $iconPath)) {
  Write-Host "icon/icon.ico not found. Place your ICO file at: $iconPath" -ForegroundColor Yellow
  exit 0
}

# Windows target path
$windowsIconDir = Join-Path $projectRoot 'windows\runner\resources'
$windowsIconPath = Join-Path $windowsIconDir 'app_icon.ico'

if (Test-Path $windowsIconDir) {
  Copy-Item -Path $iconPath -Destination $windowsIconPath -Force
  Write-Host "Copied Windows icon to: $windowsIconPath" -ForegroundColor Green
} else {
  Write-Host "Windows runner resources folder not found. Skipping Windows icon." -ForegroundColor Yellow
}

# Web target path (optional)
$webDir = Join-Path $projectRoot 'web'
$webFaviconPath = Join-Path $webDir 'favicon.ico'
if (Test-Path $webDir) {
  Copy-Item -Path $iconPath -Destination $webFaviconPath -Force
  Write-Host "Copied Web favicon to: $webFaviconPath" -ForegroundColor Green
} else {
  Write-Host "Web folder not found. Skipping web favicon.ico." -ForegroundColor Yellow
}

Write-Host "Done. Rebuild your app to see the new icons." -ForegroundColor Cyan
