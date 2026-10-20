param(
    [string]$ApkPath = 'build\app\outputs\flutter-apk\app-debug.apk',
    [string]$OutputPrefix = 'docs\presyogo-apk'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot

function Resolve-ProjectPath {
    param([string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$resolvedApk = Resolve-ProjectPath $ApkPath
$resolvedPrefix = Resolve-ProjectPath $OutputPrefix
$apkFile = Get-Item -LiteralPath $resolvedApk -ErrorAction Stop
if ($apkFile.PSIsContainer -or $apkFile.Extension -ne '.apk' -or $apkFile.Length -le 0) {
    throw 'Select an existing, non-empty APK file. No build or installation is performed by this script.'
}
$outputDirectory = Split-Path -Parent $resolvedPrefix
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$buildTools = Join-Path $env:ANDROID_HOME 'build-tools\36.0.0'
$aapt = Join-Path $buildTools 'aapt.exe'
$apksigner = Join-Path $buildTools 'apksigner.bat'
$zipalign = Join-Path $buildTools 'zipalign.exe'
foreach ($tool in @($aapt, $apksigner, $zipalign)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
        throw "Required configured Android build tool is missing: $tool"
    }
}

function Invoke-ApkInspection {
    param([string]$Tool, [string[]]$ToolArguments, [string]$Suffix)
    # Keep command output as evidence even when a native utility writes stderr.
    # Each utility's exit status is checked immediately, before another command.
    $priorErrorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $Tool @ToolArguments 2>&1 | ForEach-Object { $_.ToString() })
        $toolExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $priorErrorPreference
    }
    $logPath = "$resolvedPrefix-$Suffix.log"
    $lines | Set-Content -LiteralPath $logPath -Encoding UTF8
    if ($toolExit -ne 0) {
        throw "APK inspection '$Suffix' failed with exit code $toolExit. Inspect $logPath before claiming a pass."
    }
    return ($lines -join "`n")
}

function Require-InspectionMatch {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if ($Text -notmatch $Pattern) { throw "APK inspection failed: $Description" }
}

$badging = Invoke-ApkInspection $aapt @('dump', 'badging', $resolvedApk) 'badging'
$manifest = Invoke-ApkInspection $aapt @('dump', 'xmltree', $resolvedApk, 'AndroidManifest.xml') 'manifest'
$permissions = Invoke-ApkInspection $aapt @('dump', 'permissions', $resolvedApk) 'permissions'
$backupRules = Invoke-ApkInspection $aapt @('dump', 'xmltree', $resolvedApk, 'res/xml/backup_rules.xml') 'backup-rules'
$extractionRules = Invoke-ApkInspection $aapt @('dump', 'xmltree', $resolvedApk, 'res/xml/data_extraction_rules.xml') 'data-extraction-rules'
$signature = Invoke-ApkInspection $apksigner @('verify', '--verbose', '--print-certs', $resolvedApk) 'signature'
$alignment = Invoke-ApkInspection $zipalign @('-c', '-P', '16', '-v', '4', $resolvedApk) 'alignment'

Require-InspectionMatch $badging "(?m)^package: name='app\.presyomlang\.personal' versionCode='3' versionName='0\.2\.0'(?: |$)" 'Expected the normal personal package, version 0.2.0+3.'
Require-InspectionMatch $badging "(?m)^application-label:'PresyoGo'\s*$" 'Expected the PresyoGo launcher label.'
Require-InspectionMatch $badging "(?m)^sdkVersion:'24'\s*$" 'Expected minimum API 24.'
Require-InspectionMatch $badging "(?m)^targetSdkVersion:'36'\s*$" 'Expected target API 36.'
$abiLine = [regex]::Match($badging, '(?m)^native-code:(.*)$')
if (-not $abiLine.Success) { throw 'APK inspection failed: No native architecture line was found.' }
$actualAbis = @([regex]::Matches($abiLine.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
$expectedAbis = @('arm64-v8a', 'armeabi-v7a', 'x86_64')
$abiDifference = @(Compare-Object ($expectedAbis | Sort-Object) ($actualAbis | Sort-Object))
if ($abiDifference.Count -ne 0 -or $actualAbis.Count -ne 3) {
    throw 'APK inspection failed: Expected exactly arm64-v8a, armeabi-v7a and x86_64 native libraries.'
}

Require-InspectionMatch $manifest 'android:allowBackup\([^)]*\)=\(type 0x12\)0x0(?:\s|$)' 'Compiled allowBackup must be false.'
Require-InspectionMatch $manifest 'android:debuggable\([^)]*\)=\(type 0x12\)0xffffffff(?:\s|$)' 'Expected an explicitly debuggable internal APK.'
Require-InspectionMatch $manifest 'android:fullBackupContent\([^)]*\)=@0x[0-9a-fA-F]+' 'Compiled legacy backup-rule reference is missing.'
Require-InspectionMatch $manifest 'android:dataExtractionRules\([^)]*\)=@0x[0-9a-fA-F]+' 'Compiled modern data-extraction-rule reference is missing.'
Require-InspectionMatch $backupRules '(?m)^E: full-backup-content\b' 'Legacy backup XML root is missing.'
Require-InspectionMatch $extractionRules '(?m)^E: data-extraction-rules\b' 'Modern backup XML root is missing.'
Require-InspectionMatch $extractionRules 'E: cloud-backup\b' 'Cloud backup exclusions are missing.'
Require-InspectionMatch $extractionRules 'E: device-transfer\b' 'Device-transfer exclusions are missing.'
$domains = @('root', 'file', 'database', 'sharedpref', 'external', 'device_root', 'device_file', 'device_database', 'device_sharedpref')
foreach ($domain in $domains) {
    $pattern = 'A: domain="' + [regex]::Escape($domain) + '"'
    if ([regex]::Matches($backupRules, $pattern).Count -ne 1 -or
        [regex]::Matches($extractionRules, $pattern).Count -ne 2) {
        throw "APK inspection failed: Compiled full-domain exclusions are incomplete for $domain."
    }
}
if ([regex]::Matches($backupRules, 'E: exclude\b').Count -ne 9 -or
    [regex]::Matches($backupRules, 'A: path="\."').Count -ne 9 -or
    [regex]::Matches($extractionRules, 'E: exclude\b').Count -ne 18 -or
    [regex]::Matches($extractionRules, 'A: path="\."').Count -ne 18) {
    throw 'APK inspection failed: All nine storage domains must be fully excluded in legacy, cloud and device-transfer rules.'
}

$allowedPermissions = @('android.permission.INTERNET', 'android.permission.ACCESS_COARSE_LOCATION', 'android.permission.ACCESS_FINE_LOCATION', 'app.presyomlang.personal.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION')
$requestedPermissions = @([regex]::Matches($permissions, "(?m)^uses-permission: name='([^']+)'") | ForEach-Object { $_.Groups[1].Value })
if ($requestedPermissions.Count -ne $allowedPermissions.Count -or
    @(Compare-Object ($allowedPermissions | Sort-Object) ($requestedPermissions | Sort-Object)).Count -ne 0) {
    throw 'APK inspection failed: Expected only foreground coarse/fine location, debug-only Internet, and the AndroidX signature permission.'
}
Require-InspectionMatch $manifest 'android:protectionLevel\([^)]*\)=\(type 0x11\)0x2(?:\s|$)' 'Expected signature-level AndroidX receiver permission.'
Require-InspectionMatch $signature '(?m)^Verified using v2 scheme \(APK Signature Scheme v2\): true\s*$' 'APK Signature Scheme v2 verification must pass.'
Require-InspectionMatch $signature '(?m)^Number of signers: 1\s*$' 'Expected one internal development signer.'
Require-InspectionMatch $signature '(?m)^Signer #1 certificate DN: .*CN=Android Debug(?:,|\s|$)' 'Expected an Android Debug certificate, not a public-release signing claim.'
$expectedSignerSha256 = 'f974bbef74850490042b9c6376cb8a620899040edd1c37d21a56ee672b132720'
Require-InspectionMatch $signature "(?m)^Signer #1 certificate SHA-256 digest: $expectedSignerSha256\s*$" 'The signer must match the inspected 0.1.0 personal APK; a different debug key cannot update its notebook.'
Require-InspectionMatch $alignment '(?m)^Verification successful\s*$' '16 KiB native ZIP alignment verification must pass.'

$summary = [ordered]@{
    inspected_at_utc = [DateTime]::UtcNow.ToString('o')
    apk_path = $resolvedApk
    size_bytes = $apkFile.Length
    size_mib = [Math]::Round($apkFile.Length / 1MB, 4)
    sha256 = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash.ToLowerInvariant()
    package = 'app.presyomlang.personal'
    application_label = 'PresyoGo'
    version_name = '0.2.0'
    version_code = 3
    min_sdk = 24
    target_sdk = 36
    architectures = $actualAbis
    requested_permissions = $requestedPermissions
    certificate = 'Android Debug'
    signer_certificate_sha256 = $expectedSignerSha256
    signature_v2 = 'PASS'
    native_alignment_16k = 'PASS'
    compiled_backup_exclusions = 'PASS; manufacturer transfer behavior requires a device test'
    installation = 'NOT RUN by this inspection script'
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$resolvedPrefix-summary.json" -Encoding UTF8
[PSCustomObject]$summary
