# Drift schema snapshots and verification

The app creates its constrained schema through explicit SQL. Drift's documented
schema dump command accepts an existing SQLite file, so we export a fresh,
empty test-owned file created by the real application database. See
[Drift schema exports](https://drift.simonbinder.eu/migrations/exports/).

After dependency resolution, run from the project root:

```powershell
. .\scripts\env.ps1
flutter pub get
.\scripts\export-schema.ps1
flutter test test/migrations/initial_schema_test.dart --concurrency=1
```

The script creates a temporary empty SQLite database, runs `drift_dev schema dump`
into `drift_schemas/official/drift_schema_v1.json`, and runs `drift_dev schema generate`
on that official-only directory into `test/generated_migrations`. It creates the
official output directory and removes only its own temporary directory. The
older `drift_schemas/schema_v1.json` inspection snapshot and its existing tests are
retained separately and are not rewritten by the temporary-file export. This
keeps their schema-change regression check effective. Commit the official
snapshot and generated helper files.
The normal `scripts/build-debug.ps1` resolves dependencies and generates these
helpers before formatting, analysis and tests; formatting includes the entire
`test` directory, including generated helpers and migration verification.

`SchemaVerifier(GeneratedHelper())` compares the real initial schema to the
official snapshot, then verifies a populated version 1 database after reopening.
A negative test adds an unexpected table and requires schema mismatch detection.
This follows [Drift migration testing](https://drift.simonbinder.eu/migrations/tests/)
without inventing an earlier released schema. There is no v1-to-v2 migration yet.

When the schema genuinely changes, retain the v1 snapshot, increment the actual
schema version, implement the migration, export the new official snapshot and
regenerate helpers. Add a populated old-to-new migration test covering IDs,
quotes, purchases, frozen snapshots, totals and foreign keys. Never delete a
database to resolve migration failure.

The development tool is pinned to `drift_dev: 2.35.1`. Its published dependency
range includes Drift 2.35.2 (`>=2.30.0 <2.36.0`); there is no published drift_dev
2.35.2. Runtime code and runtime dependency versions are unchanged. Preparation
of this workflow is not evidence that generation or its new tests have passed;
record actual execution in `VERIFICATION.md` after running the commands.
