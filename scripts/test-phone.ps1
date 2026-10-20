param([string]$DeviceId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$normalPackage = 'app.presyomlang.personal'
$integrationPackage = 'app.presyomlang.personal.integration'
$integrationFlag = 'ORG_GRADLE_PROJECT_PRESYO_INTEGRATION_TARGET'
$previousIntegrationFlag = [Environment]::GetEnvironmentVariable($integrationFlag, 'Process')
$aapt = Join-Path $env:ANDROID_HOME 'build-tools\36.0.0\aapt.exe'
if (-not (Test-Path -LiteralPath $aapt)) { throw 'The configured Android build-tools 36.0.0/aapt.exe is required to verify APK identities.' }

function Assert-ApkPackage {
    param([string]$ApkPath, [string]$ExpectedPackage)
    if (-not (Test-Path -LiteralPath $ApkPath)) { throw 'The APK to inspect does not exist.' }
    $badging = @(& $aapt dump badging $ApkPath 2>&1)
    $inspectionExit = $LASTEXITCODE
    $packageMatch = [regex]::Match(($badging -join "`n"), "(?m)^package: name='([^']+)'")
    if ($inspectionExit -ne 0 -or -not $packageMatch.Success -or $packageMatch.Groups[1].Value -ne $ExpectedPackage) {
        throw "APK package verification failed; expected $ExpectedPackage. No installation was attempted."
    }
}

$connected = @(& adb devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
if (-not $DeviceId) {
    if ($connected.Count -ne 1) { throw 'Connect and authorize exactly one Android phone, or provide -DeviceId.' }
    $DeviceId = $connected[0]
}
if ($DeviceId -notin $connected) { throw 'The selected Android device is not connected and authorized.' }
$currentAndroidUser = (& adb -s $DeviceId shell am get-current-user).Trim()
if ($LASTEXITCODE -ne 0 -or $currentAndroidUser -notmatch '^\d+$') {
    throw 'Could not identify the current Android user. No installation was attempted.'
}

Push-Location -LiteralPath $projectRoot
try {
    & adb -s $DeviceId shell getprop ro.product.model
    & adb -s $DeviceId shell getprop ro.build.version.release

    # Flutter may automatically uninstall an incompatible old test harness.
    # Only the isolated integration package is ever exposed to that behavior.
    [Environment]::SetEnvironmentVariable($integrationFlag, 'true', 'Process')
    & flutter build apk --debug --target integration_test/app_test.dart --android-project-arg=PRESYO_INTEGRATION_TARGET=true
    if ($LASTEXITCODE -ne 0) { throw 'Isolated integration APK build failed.' }
    $apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    Assert-ApkPackage -ApkPath $apkPath -ExpectedPackage $integrationPackage
    & flutter test integration_test/app_test.dart -d $DeviceId --device-user=$currentAndroidUser
    if ($LASTEXITCODE -ne 0) { throw 'Phone integration tests failed.' }

    # Reset the Gradle flag before rebuilding and inspecting the normal app.
    [Environment]::SetEnvironmentVariable($integrationFlag, 'false', 'Process')
    & flutter build apk --debug --target lib/main.dart --android-project-arg=PRESYO_INTEGRATION_TARGET=false
    if ($LASTEXITCODE -ne 0) { throw 'Normal app rebuild failed after integration tests.' }
    Assert-ApkPackage -ApkPath $apkPath -ExpectedPackage $normalPackage

    # Direct ADB update only: never uninstall the personal notebook on failure.
    $installOutput = @(& adb -s $DeviceId install --user $currentAndroidUser -r $apkPath 2>&1)
    $installExit = $LASTEXITCODE
    $installOutput | Write-Output
    if ($installExit -ne 0 -or ($installOutput -join "`n") -match '(?im)^\s*Failure\b' -or
        ($installOutput -join "`n") -notmatch '(?m)^Success\s*$') {
        throw 'APK update failed. The personal notebook was not uninstalled. Preserve its manual backup before resolving any signature or device issue.'
    }
    $launchOutput = @(& adb -s $DeviceId shell am start -W --user $currentAndroidUser -n "$normalPackage/.MainActivity" 2>&1)
    $launchExit = $LASTEXITCODE
    $launchOutput | Write-Output
    if ($launchExit -ne 0 -or ($launchOutput -join "`n") -match '(?im)^\s*(Error|Exception)\b' -or
        ($launchOutput -join "`n") -notmatch '(?im)^Status:\s*ok\s*$') {
        throw 'App launch was not confirmed. Inspect the device before recording an install/open pass.'
    }
} finally {
    [Environment]::SetEnvironmentVariable($integrationFlag, $previousIntegrationFlag, 'Process')
    Pop-Location
}
