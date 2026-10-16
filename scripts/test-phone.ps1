param([string]$DeviceId)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$connected = @(& adb devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
if (-not $DeviceId) {
    if ($connected.Count -ne 1) { throw 'Connect and authorize exactly one Android phone, or provide -DeviceId.' }
    $DeviceId = $connected[0]
}
if ($DeviceId -notin $connected) { throw 'The selected Android device is not connected and authorized.' }
Push-Location -LiteralPath $projectRoot
try {
    & adb -s $DeviceId shell getprop ro.product.model
    & adb -s $DeviceId shell getprop ro.build.version.release
    & flutter test integration_test/app_test.dart -d $DeviceId
    if ($LASTEXITCODE -ne 0) { throw 'Phone integration tests failed.' }
    # Integration tests may replace the build output with a test-harness APK.
    # Rebuild the normal entry point before installing the user's app.
    & flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'Normal app rebuild failed after integration tests.' }
    & adb -s $DeviceId install -r (Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk')
    if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
    & adb -s $DeviceId shell am start -n app.presyomlang.personal/.MainActivity
    if ($LASTEXITCODE -ne 0) { throw 'App launch failed.' }
} finally { Pop-Location }
