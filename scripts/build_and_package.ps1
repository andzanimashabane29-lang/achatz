# A-Chatz Build & Package Script
# Compiles Android and Web targets, then packages them with the marketing site.

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

$flutter = "c:\flutter\flutter\bin\flutter.bat"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "           A-Chatz Build Pipeline         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Build Android APK
Write-Host "`n[1/4] Compiling Android Release APK..." -ForegroundColor Yellow
& $flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Android build failed."
    exit 1
}

# 2. Build Web App (PWA)
Write-Host "`n[2/4] Compiling Flutter Web Release..." -ForegroundColor Yellow
& $flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Web build failed."
    exit 1
}

# 3. Assemble Deploy Directory
Write-Host "`n[3/4] Initializing deployment folder (build\deploy)..." -ForegroundColor Yellow
$DeployDir = "build\deploy"
if (Test-Path $DeployDir) {
    Remove-Item -Path $DeployDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $DeployDir | Out-Null

# 4. Copy Marketing Site
Write-Host "Copying marketing site files..." -ForegroundColor Gray
Copy-Item -Path "a_chatz_marketing_site\*" -Destination $DeployDir -Recurse -Force

# 5. Copy Android APK
Write-Host "Copying release APK..." -ForegroundColor Gray
$ApkSrc = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $ApkSrc) {
    Copy-Item -Path $ApkSrc -Destination "$DeployDir\a-chatz.apk" -Force
} else {
    Write-Error "Release APK not found at $ApkSrc!"
    exit 1
}

# 6. Copy Web App to /app/
Write-Host "Copying Flutter Web build to subfolder /app/..." -ForegroundColor Gray
New-Item -ItemType Directory -Force -Path "$DeployDir\app" | Out-Null
Copy-Item -Path "build\web\*" -Destination "$DeployDir\app" -Recurse -Force

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "          Build & Package Complete!       " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "`nDeployable folder located at: build\deploy"
Write-Host "To launch/deploy the app to the web, run:"
Write-Host "  firebase deploy" -ForegroundColor Cyan
Write-Host "=========================================="
