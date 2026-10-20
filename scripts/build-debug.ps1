param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    # Generate official Drift helpers before formatting, analysis or tests import
    # them. The test directory includes both generated and migration test files.
    & (Join-Path $PSScriptRoot 'export-schema.ps1')
    & dart format --output=none --set-exit-if-changed lib test integration_test tool
    if ($LASTEXITCODE -ne 0) { throw 'Formatting check failed.' }
    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
    if (-not $SkipTests) {
        & flutter test --concurrency=1
        if ($LASTEXITCODE -ne 0) { throw 'Automated tests failed.' }
    }
    & flutter build apk --debug --target lib/main.dart --android-project-arg=PRESYO_INTEGRATION_TARGET=false
    if ($LASTEXITCODE -ne 0) { throw 'Android debug APK build failed.' }
    $apkFile = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    Get-Item -LiteralPath $apkFile | Select-Object FullName,Length,LastWriteTime
    Get-FileHash -LiteralPath $apkFile -Algorithm SHA256
    $handoffDirectory = Join-Path $projectRoot 'dist'
    New-Item -ItemType Directory -Force -Path $handoffDirectory | Out-Null
    $handoffApk = Join-Path $handoffDirectory 'PresyoGo-0.2.0-debug.apk'
    Copy-Item -LiteralPath $apkFile -Destination $handoffApk
    & (Join-Path $PSScriptRoot 'inspect-apk.ps1') -ApkPath $handoffApk
} finally { Pop-Location }
