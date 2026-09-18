# Builds/runs A-Chatz on Windows without MAX_PATH (260 char) errors.
# Your Downloads path is too long for MSVC + Firebase native plugins.

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ShortLink = "C:\achatz"

if (-not (Test-Path $ShortLink)) {
    Write-Host "Creating junction: $ShortLink -> $ProjectRoot"
    cmd /c mklink /J $ShortLink $ProjectRoot | Out-Null
    if (-not (Test-Path $ShortLink)) {
        Write-Error "Failed to create C:\achatz junction. Run PowerShell as Administrator or move the project to e.g. C:\dev\achatz"
        exit 1
    }
}

Set-Location $ShortLink
$flutter = "c:\flutter\flutter\bin\flutter.bat"

if ($args.Count -eq 0) {
    & $flutter run -d windows
} else {
    & $flutter @args
}
