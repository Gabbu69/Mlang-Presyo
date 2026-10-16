# Dot-source this script: . .\scripts\env.ps1
# Changes only the current PowerShell session; no machine/user settings are changed.
$env:FLUTTER_ROOT = 'G:\DevTools\flutter'
$env:JAVA_HOME = 'G:\DevTools\jdk-17'
$env:ANDROID_HOME = 'G:\DevTools\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = 'G:\DevCaches\android'
$env:PUB_CACHE = 'G:\DevCaches\pub'
$env:GRADLE_USER_HOME = 'G:\DevCaches\gradle'
$env:TEMP = 'G:\DevTemp'
$env:TMP = $env:TEMP
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
@($env:ANDROID_USER_HOME, $env:PUB_CACHE, $env:GRADLE_USER_HOME, $env:TEMP) |
    ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
$toolPaths = @(
    "$env:FLUTTER_ROOT\bin",
    "$env:JAVA_HOME\bin",
    "$env:ANDROID_HOME\cmdline-tools\latest\bin",
    "$env:ANDROID_HOME\platform-tools"
)
$env:PATH = ($toolPaths + ($env:PATH -split ';' | Where-Object { $_ -notin $toolPaths })) -join ';'
