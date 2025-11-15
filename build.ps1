param()

Set-StrictMode -Version Latest

Write-Host "=== Windows PowerShell Flutter web build script ==="

$ErrorActionPreference = 'Stop'

$flutterVersion = '3.16.9'
$flutterZip = "flutter_windows_${flutterVersion}-stable.zip"
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/$flutterZip"
$flutterDir = Join-Path $PSScriptRoot 'flutter'

function Download-Flutter {
    if (Test-Path $flutterDir) {
        Write-Host "Flutter already present in $flutterDir"
        return
    }

    Write-Host "Downloading Flutter $flutterVersion..."
    $zipPath = Join-Path $PSScriptRoot $flutterZip
    Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Extracting..."
    Expand-Archive -Path $zipPath -DestinationPath $PSScriptRoot -Force
    Remove-Item $zipPath -Force
}

Download-Flutter

$env:PATH = "$flutterDir\bin;$env:PATH"

Write-Host "=== Enabling web support and verifying flutter ==="
& flutter.bat config --enable-web
& flutter.bat --version

Write-Host "=== Getting dependencies ==="
& flutter.bat pub get

Write-Host "=== Building web (release) ==="
& flutter.bat build web --release

Write-Host "=== Build complete: build/web ==="
if (Test-Path (Join-Path $PSScriptRoot 'build\web')) {
    Get-ChildItem -Path (Join-Path $PSScriptRoot 'build\web') -Force
} else {
    Write-Error "build/web not found after build"
}
