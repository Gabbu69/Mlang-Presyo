# PresyoGo

**Your prices, wherever you shop.** An offline Flutter Android price notebook,
shopping planner and grocery spending companion for personal use anywhere in the
Philippines. Current update: **0.2.0+3**, internal application ID
**app.presyomlang.personal** (preserved from Presyo M’lang for update compatibility).

The 0.2.0 location and rebranding update is being verified. Current results and
the inspected APK identity are recorded in `docs/VERIFICATION.md`; older checks
below remain historical. Physical phone checks require a connected device.

## Historical review — 0.1.1

Historically, the 0.1.1 review update passed static analysis, all **93 Flutter host tests** and
all **7 native JVM writer tests**. On the authorized TECNO KL7 running Android 14,
the first isolated SQLite shopping/purchase/reopen/backup journey passed. Its
2,000-record search test exposed a real search-field retention bug, now fixed and
covered by a regression; the complete phone rerun remains pending. Updated normal
APK inspection, manual device checks and source push are also pending. The
earlier 0.1.0 artifact does not contain these review fixes. Consult
`docs/VERIFICATION.md` for the separate results and their limits.

The review fixes pending-save navigation, hidden manual estimates, list recency
ordering, recovery after a committed write's reload fails, complete snapshot
validation, portable backup capacity and search retention after lazy field
disposal/recreation. Android exports now confirm checked
write/flush/close completion. That review retained schema 1 and backup format 1. The
concrete findings and regression evidence are in `docs/V1_REVIEW_2026-10-17.md`.

## Included

- Four tabs: Home, Lists, Prices and Spending; Settings in the app bar.
- Product/store creation within price entry, dated observations, filters and history.
- Like-for-like comparisons, exact unit values, newest-offer selection and visible dates.
- Whole-package or loose-quantity estimates; frozen price bases and explicit refresh.
- Shopping budgets, explicit purchases, atomic undo and duplicate-save protection.
- Monthly/category spending from the actual purchase ledger and historical snapshots.
- Versioned JSON backup, validated transactional replacement restore, and formula-safe CSV.
- Separate fictional demo database, private real records, and confirmed local reset.
- Optional Shopping area: All areas, a manually named area, or saved stores within
  5, 10 or 25 km of an explicitly captured phone location. Default: All areas.
- Explicit store location tags, visible price scope, and a Show all areas override.

Tap Use my location and Save shopping area when you arrive somewhere. Saved
positions show their capture time and accuracy; tap Refresh location to capture
again. Approximate distance filters your own records. GPS does not fetch prices,
discover stores, detect city names, or track travel automatically. Without a fix
or permission, manual areas and All areas remain usable offline. Saving a shopping
area never assigns that position to stores; tagging a store is a separate action.

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
a failed check, copies the local handoff to `dist/PresyoGo-0.2.0-debug.apk` and
inspects its identity, permissions, signature, alignment and backup rules. This is
a development APK, not a public release-signed build.

## APK handoff and installation

Use the **0.2.0+3** artifact evidence in `docs/VERIFICATION.md` before installing
`dist/PresyoGo-0.2.0-debug.apk`; a file is verified only after inspection passes. The
following table preserves the **previous 0.1.0+1** artifact identity; it must not
be used as evidence that the review update has been built.

Previous inspected handoff: `dist/Presyo-Mlang-0.1.0-debug.apk`.

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
4. Tap Install, then Open. The app name is **PresyoGo**. It is an internal
   development build signed for testing, without public release signing.
5. Turn off that install permission again when finished, then follow
   `docs/PHONE_CHECKLIST.md` and record your actual results.

Do not uninstall an existing notebook to resolve an update/signature problem
before exporting its records; uninstalling can remove the local database.
Installation, opening and physical-phone checks for the update remain **PENDING**
until observed on the authorized phone.

For the optional automated integration checks, connect and authorize your phone
on the development computer, then run:

```powershell
.\scripts\test-phone.ps1
```

Read `docs/PHONE_CHECKLIST.md` for airplane-mode, force-stop, TalkBack, picker and
restore checks. Phone integration tests now use the isolated
`app.presyomlang.personal.integration` package and a separate temporary database.
The script verifies package identities and updates the normal app through direct
ADB without automatically uninstalling the personal notebook. Back up any
existing installation before testing a development update.

## Data and backups

Money uses integer centavos. Quantities use grams, milliliters or pieces; kg/L
conversion is exact. Business dates use Asia/Manila. Quotes never become expenses
automatically, and missing estimates are not zero.

Database schema 2 upgrades schema 1 without deleting records. JSON backup format 2
is separate from the database version; restore also accepts existing format 1
backups with safe empty location defaults. Restore accepts only fully validated
backups of at most 10 MiB and 20,000 aggregate records/settings,
then replaces data in one transaction after confirmation. CSV cannot be restored.
Exports are **not encrypted** and may include saved area labels, coordinates,
accuracy and capture times. New filenames use `presyogo_`; old backup filenames
remain supported. Uninstalling can remove records; exported copies
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
- `docs/V1_REVIEW_2026-10-17.md`: 0.1.1 review findings, fixes and remaining verification gates.
- `CODEX_PROMPTS.md` and `SOURCES.md`: original build-kit prompts and primary references.

The approved full-V1 request supersedes the original example prompt to stop at M1.
The original 0.1.0 source, tests, documentation and lockfile were published to
[Gabbu69/Presyo-M-lang](https://github.com/Gabbu69/Presyo-M-lang) on `main`, as
authorized by the owner. The newer review/location source changes have not been
published by this local milestone. The version-specific push evidence is in `docs/VERIFICATION.md`.
No application backend or paid service is required. Public APK distribution and
Play Store publication remain separate from this source publication.
