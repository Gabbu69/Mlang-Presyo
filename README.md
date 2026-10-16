# Presyo M’lang

An offline Flutter Android price notebook, shopping planner and grocery spending
companion. Version **0.1.0+1**, internal application ID
**app.presyomlang.personal**. Designed for personal use in M’lang, North Cotabato.

The Android development APK has been built and inspected. Source, automated
checks and artifact evidence are in this workspace; physical-phone installation
and testing are **NOT RUN**, deferred by the owner. Consult `docs/VERIFICATION.md`
for the exact checks and their limits.

## Included

- Four tabs: Home, Lists, Prices and Spending; Settings in the app bar.
- Product/store creation within price entry, dated observations, filters and history.
- Like-for-like comparisons, exact unit values, newest-offer selection and visible dates.
- Whole-package or loose-quantity estimates; frozen price bases and explicit refresh.
- Shopping budgets, explicit purchases, atomic undo and duplicate-save protection.
- Monthly/category spending from the actual purchase ledger and historical snapshots.
- Versioned JSON backup, validated transactional replacement restore, and formula-safe CSV.
- Separate fictional demo database, private real records, and confirmed local reset.

Real mode starts empty. This is an independent notebook, with no verified live
price feed, official partnership, community posting, account, backend, analytics,
advertising, maps, payment processing or automatic sharing.

## Develop on this Windows machine

Tools, caches and temporary build files are configured on G. The setup script
changes only the current PowerShell session and preserves the installed system Java.

```powershell
Set-Location -LiteralPath 'G:\Mlang Presyo'
. .\scripts\env.ps1
flutter doctor -v
flutter pub get
flutter run -d YOUR_CONNECTED_DEVICE_ID
```

Use the actual device ID from `flutter devices`; do not paste the placeholder.
If SDK terms are required, the owner must review and accept those terms.

```powershell
.\scripts\build-debug.ps1
```

The build script checks formatting, analysis, automated tests and the database
schema before building `build/app/outputs/flutter-apk/app-debug.apk`. It stops on
a failed check. This is a development APK, not a public release-signed build.

## Install the APK on your phone later

The inspected handoff APK is `dist/Presyo-Mlang-0.1.0-debug.apk`.

| Artifact detail | Verified value |
|---|---|
| Version | 0.1.0+1 |
| Minimum Android | Android 7.0 / API 24 |
| Target API | 36 |
| Architectures | arm64-v8a, armeabi-v7a, x86_64 |
| Size | 168,734,527 bytes / 160.9187 MiB |
| SHA-256 | `2632f4921eacb54af009d36bf949d1461728697cdfd47c4bba19b57a7aa51022` |
| Signature/alignment | Android Debug certificate; APK Signature Scheme v2 and 16 KiB alignment checks PASS |

The APK is a local handoff artifact excluded from Git. The GitHub source
repository does not automatically distribute this binary. See
`docs/VERIFICATION.md` for the inspection logs and remaining phone checks.

1. If updating an installation that contains records, save a manual JSON backup
   from Settings first. Keep that backup outside the app.
2. Transfer the inspected APK to your Android phone by USB file transfer or
   another transfer method you choose. You do not need Flutter on the phone.
3. Open the APK with the phone's Files app. If Android asks, temporarily allow
   **Install unknown apps** for the particular Files/browser app opening it.
4. Tap Install, then Open. The app name is **Presyo M’lang**. It is an internal
   development build signed for testing, without public release signing.
5. Turn off that install permission again when finished, then follow
   `docs/PHONE_CHECKLIST.md` and record your actual results.

Do not uninstall an existing notebook to resolve an update/signature problem
before exporting its records; uninstalling can remove the local database.
Installation, opening and physical-phone checks remain **NOT RUN** until observed.

For the optional automated integration checks, connect and authorize your phone
on the development computer, then run:

```powershell
.\scripts\test-phone.ps1
```

Read `docs/PHONE_CHECKLIST.md` for airplane-mode, force-stop, TalkBack, picker and
restore checks. Phone integration tests use a separate temporary test database;
they do not open or reset your real notebook. Back up any existing installation
before testing a development update.

## Data and backups

Money uses integer centavos. Quantities use grams, milliliters or pieces; kg/L
conversion is exact. Business dates use Asia/Manila. Quotes never become expenses
automatically, and missing estimates are not zero.

JSON backup format 1 is independent of database schema version 1. Restore accepts
only fully validated backups of at most 10 MiB and 20,000 aggregate records/settings,
then replaces data in one transaction after confirmation. CSV cannot be restored.
Exports are **not encrypted**. Uninstalling can remove records; exported copies
cannot be retracted by deleting in-app data.

Android backup and transfer exclusions are configured. Manufacturer-specific
device-transfer prevention requires separate verification and is not guaranteed.

## Project references

- `PRODUCT_SPEC.md` and `ACCEPTANCE_TESTS.md`: supplied behavior and acceptance contract.
- `PLANS.md`: milestone status, updated from evidence.
- `docs/DECISIONS.md`: implementation choices and boundaries.
- `docs/BUILD_LOG.md`, `docs/ENVIRONMENT.md`, `docs/VERIFICATION.md`: actual execution evidence.
- `docs/IMPLEMENTATION_CONTRACT.md`: repository/domain interfaces and logical backup shape.
- `docs/SCHEMA_WORKFLOW.md`: official Drift snapshots, generated helpers and schema verification.
- `CODEX_PROMPTS.md` and `SOURCES.md`: original build-kit prompts and primary references.

The approved full-V1 request supersedes the original example prompt to stop at M1.
The owner explicitly authorized publishing source, tests, documentation and the
lockfile to [Gabbu69/Presyo-M-lang](https://github.com/Gabbu69/Presyo-M-lang) on
`main` after final checks. Final source publication is reported from verified Git
commit/push evidence in the handoff; an authorized or configured remote alone
does not mean the push has completed.
No application backend or paid service is required. Public APK distribution and
Play Store publication remain separate from this source publication.
