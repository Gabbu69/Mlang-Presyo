$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$schemaTempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
$schemaTempDirectory = Join-Path $schemaTempRoot ('presyo_schema_' + [Guid]::NewGuid().ToString('N'))
$schemaSourceFile = Join-Path $schemaTempDirectory 'schema_v2.sqlite'
New-Item -ItemType Directory -Path $schemaTempDirectory | Out-Null
Push-Location -LiteralPath $projectRoot
try {
    & dart run tool/export_schema.dart
    if ($LASTEXITCODE -ne 0) { throw 'Inspectable SQLite schema export failed.' }

    # Pub dependencies must already be resolved. This command creates an empty,
    # test-owned database through the app's real onCreate implementation.
    & dart run tool/export_schema.dart --sqlite-output $schemaSourceFile
    if ($LASTEXITCODE -ne 0) { throw 'SQLite schema source creation failed.' }

    # Documented Drift tooling supports introspecting a SQLite file directly.
    New-Item -ItemType Directory -Force -Path 'drift_schemas/official' | Out-Null
    & dart run drift_dev schema dump $schemaSourceFile 'drift_schemas/official/drift_schema_v2.json'
    if ($LASTEXITCODE -ne 0) { throw 'Official Drift schema export failed.' }
    & dart run drift_dev schema generate 'drift_schemas/official' 'test/generated_migrations'
    if ($LASTEXITCODE -ne 0) { throw 'Drift schema helper generation failed.' }
} finally {
    Pop-Location
    # Validate the absolute cleanup target before recursively removing it.
    $schemaCleanupPath = [IO.Path]::GetFullPath($schemaTempDirectory)
    if (-not $schemaCleanupPath.StartsWith($schemaTempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not [IO.Path]::GetFileName($schemaCleanupPath).StartsWith('presyo_schema_', [StringComparison]::Ordinal)) {
        throw 'Refusing cleanup outside the task-owned schema temporary directory.'
    }
    if (Test-Path -LiteralPath $schemaCleanupPath) {
        Remove-Item -LiteralPath $schemaCleanupPath -Recurse -Force
    }
}
