# Implementation decisions

Date: 16 October 2026 (Asia/Manila). Version 0.1.0 internal Android pilot.

- The user's full V1 request authorizes M0 through M6 sequentially; the kit's example prompt to stop at M1 does not limit this implementation.
- Workspace is `G:\Mlang Presyo`. The kit's inner files are placed at this root.
- Application ID is `app.presyomlang.personal`. Public release signing, APK distribution and Play Store publication remain outside this internal build. The owner later explicitly authorized source/tests/docs/lockfile publication to `https://github.com/Gabbu69/Presyo-M-lang.git`, branch `main`, after final checks. This source push does not publish the local APK.
- Toolchain, caches and build temporary files live on G. Environment changes are session scoped. Existing system Java is preserved. New SDK terms require owner review.
- The application uses Riverpod controllers, Drift native SQLite transactions, and separate UI/core/data files. Validated JSON-compatible Row maps are the internal entity representation so form drafts, database serialization and logical backups use the same field names.
- Drift uses explicit constrained SQL with schema version 1 rather than generated companions. Official Drift SQLite-file dump/generation and SchemaVerifier tests supplement the custom inspection snapshot. Quoted `key`/`value` identifiers keep the actual SQL compatible with the schema parser; initial unreleased v1 snapshots were regenerated without changing table layout. Unknown upgrades fail without deleting data. The first real schema upgrade requires a reviewed migration and data-preservation tests.
- Money is integer centavos and quantities integer g/mL/pieces; comparisons use BigInt fractions. Zero is valid actual money/manual estimates/budgets; absent values are null. All quantities and quoted prices are positive.
- Business dates use UTC+08:00 Manila independently of device timezone; technical timestamps use UTC. Future observations and purchases are rejected.
- Product identity is the user-selected product ID. The form explains brand/variant/grade distinctions and warns on duplicate-looking names; there is no automatic merge or brand inference.
- Requested-quantity edits clear manual totals; price-based estimates recalculate from frozen snapshots. Duplicate lists clear estimates and purchases. Actual quantity edits preserve planned quantity.
- One linked purchase per item is enforced in SQLite and repository transactions. Undo/delete returns the linked item to Needed. Purchase and category snapshots preserve history.
- Monthly budgets are per explicit YYYY-MM and do not carry to another month.
- Real and demo SQLite files are physically separate. Demo is persistently labeled. Real backup/restore/export/reset are unavailable in demo; demo has its own reset.
- JSON backup format 1 is independent of SQLite schema version. Caps are 10 MiB UTF-8 and 20000 aggregate rows. Restore validates before a replacement transaction. CSV is export-only and text fields neutralize spreadsheet formulas.
- Native file picker dialogs save exports and select backups without broad storage permission. Exports are unencrypted and destination retention is disclosed.
- Android automatic backup and device transfer exclusions are configured. Manufacturer-specific transfer prevention is not claimed without a device test.
- Light theme, system fonts, simple English, accessible deep-green/cream palette. No runtime fonts, backend, accounts, network client, analytics, ads, GPS, payments or automatic sharing.
- Home's decorative introduction is compact and omitted above 150% text scaling, keeping actions and shopping figures ahead of decoration. Static interface copy lives in central English copy files; dynamic templates remain beside their presentation until reviewed localization is introduced.
- The supplied project guidance requests a committed application lockfile. A new local Git repository was initialized because the workspace had none. Source history includes the lockfile. The later owner-authorized source push targets the verified empty public GitHub repository on `main`; origin is configured and push permission was confirmed. Report the observed commit/push result in the final handoff rather than inferring remote completion from local files or remote configuration.
- Physical-phone testing is deferred by the owner's later instruction. APK compilation and host verification continue independently; phone acceptance remains a separate handoff.

See BUILD_LOG.md and VERIFICATION.md for the successful APK inspection, final 69-test host result and the still-deferred phone checks. Build verification, source publication and physical-phone acceptance are separate evidence boundaries.
