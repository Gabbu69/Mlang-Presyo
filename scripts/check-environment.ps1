# Read-only environment diagnostics. Does not accept Android licenses.
. "$PSScriptRoot\env.ps1"
& java -version
& flutter --version
& flutter doctor -v
& flutter devices
if (Test-Path "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat") {
    & "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$env:ANDROID_HOME" --list_installed
}
if (Test-Path "$env:ANDROID_HOME\platform-tools\adb.exe") {
    & "$env:ANDROID_HOME\platform-tools\adb.exe" devices -l
}
