# Build log

## 16 October 2026 — M0 initialization

- Inspected empty workspace and supplied ZIP; preserved seven kit planning files at workspace root.
- Existing tools: Git and system Temurin Java 25. No usable Flutter/Android toolchain found. Existing C Android SDK was incomplete.
- Owner selected full offline V1, G-local tools/caches and physical Android phone testing.
- Toolchain installation and checksum verification in progress; no SDK terms accepted automatically.

## M1–M5 source implementation in progress

- Added separated app shell/controller/theme, catalog and price-entry flows, comparison/history screens, lists and estimates, explicit purchases, spending, Settings and native portability dialogs.
- Added exact domain helpers and SQLite repository/portability implementations with automated tests.
- Compilation, formatting, analysis and execution are pending the actual Flutter/Dart toolchain. Source presence is not verification.

Further command results and milestone gates will be appended from actual output.

## First runtime verification

- `flutter pub get`: PASS, resolved 83 dependencies and created application lockfile. Flutter 3.47.7 / Dart 3.13.5, Drift 2.35.2, Riverpod 3.4.3, sqlite3 3.7.1, file_picker 13.1.0.
- Initial `flutter analyze` encountered an SDK-installation issue because sparse SDK checkout omitted the examples root. Restored the official example/dev package metadata paths; no application behavior was changed to work around it.
- Direct `dart analyze --format machine`: exit 0; no compiler errors/warnings, 74 informational style findings. Style cleanup and standard Flutter analysis are pending.
- `dart run tool/export_schema.dart`: PASS, exported 12 actual SQLite schema entities (eight tables, three indexes, one trigger) to `drift_schemas/schema_v1.json`.
- `flutter test test/domain test/data --concurrency=1 --reporter expanded`: PASS, 50 tests. Tests include exact arithmetic, freshness/timezone rules, frozen snapshots, concurrent saves, rollback, foreign keys, host SQLite reopen, backup round trip/rejection, demo isolation and CSV escaping.
- Drift debug warning appears in tests intentionally opening separate connections for round-trip/isolation checks; no connection is shared across those databases. The application opens only the selected personal/demo connection and closes it before switching.
- Independent UI review fixed disappearing category/store filters after catalog changes/restore, budget-write draft retention, explicit older-price opt-in in estimate selection, earliest-date picker range, and inline product/store form retention. Regression widget tests were added; execution pending.
- Owner explicitly deferred physical-phone tests and requested APK completion first. No more device polling is required. Phone checks remain NOT RUN.

## UI verification and Android build

- `dart fix --apply`: applied 72 style fixes without weakening assertions; replaced the remaining deprecated test connection close method. `flutter analyze`: PASS, no issues found.
- Initial complete suite: 60 passed, 6 UI tests failed. Corrected test scrolling to reveal and center lazy form controls. Preserved both controller and visible-text draft assertions. Reworked the budget fault fixture to hold a real in-flight write before testing duplicate taps, then fail and retry.
- `flutter test test/widgets/app_flow_test.dart --concurrency=1 --reporter expanded`: PASS, all 16 UI/regression/render tests.
- Generated and visually inspected readable widget renders for Home, Prices, Lists, Spending and 320px/200% text. These use fictional test fixtures and are not Android screenshots.
- Compacted the Home introduction and omitted it at large text scales so primary actions and shopping data appear first.
- Final formatting check at this stage: PASS, 25 Dart files, zero changes.
- `flutter doctor -v`: completed. Exact official Flutter tag appears as `[user-branch]` because it is pinned to a detached release commit. Android components/Java are detected; doctor reports additional unaccepted SDK licenses. No new terms were auto-accepted. Visual Studio's missing Windows SDK is unrelated to this Android target. Android build is being attempted with the installed components; required license blockers, if any, will be reported from actual build output.
- `flutter build apk --debug`: running. The Flutter migrator added its AGP compatibility flags to the low-memory Gradle configuration. Gradle uses its checksum-verified 9.3.1 binary distribution, one worker and a 1024 MiB heap. APK success is pending actual output inspection.

## Final host verification and diagnostic APK retry

- Final `dart format --output=none --set-exit-if-changed lib test integration_test tool`: PASS, 25 files, zero changes (`format-final.log`).
- Final `flutter analyze`: PASS, no issues found (`analyze-final.log`).
- Final `flutter test --concurrency=1 --reporter expanded`: PASS, all 66 tests in one complete run (`tests-final.log`).
- The first quiet APK attempt spent approximately 21 minutes compiling the Flutter Gradle plugin and downloading dependencies. Thread inspection showed HTTP dependency downloads; 667 completed dependency files were cached. It was deliberately stopped to enable verbose diagnostics, so its daemon-disappeared error reflects the intentional stop and is not claimed as an application failure or memory crash.
- Restarted `flutter build apk --debug --verbose`, retaining completed caches. The exact task/download progress is recorded in `apk-build-verbose.log`. Output inspection remains pending.

## Completed Android artifact and final verification

- `flutter build apk --debug --verbose`: PASS after 1 hour 54 minutes 20 seconds including cold-cache downloads and compilation. Android API 35 revision 2 and CMake 3.22.1 were installed on G using the existing license acceptance. No new terms were automatically accepted. AGP/Kotlin compatibility deprecation warnings remain.
- Inspected `build/app/outputs/flutter-apk/app-debug.apk` and verified its handoff copy at `dist/Presyo-Mlang-0.1.0-debug.apk`: 168,734,527 bytes (160.9187 MiB), SHA-256 `2632f4921eacb54af009d36bf949d1461728697cdfd47c4bba19b57a7aa51022`.
- AAPT inspection: version 0.1.0+1, application ID `app.presyomlang.personal`, minimum API 24/Android 7.0, target API 36, arm64-v8a/armeabi-v7a/x86_64 libraries. Signature verification: PASS, APK v2 with Android Debug certificate. 16 KiB alignment verification: PASS.
- Compiled manifest and backup resources inspected: allowBackup=false and explicit cloud/device-transfer exclusions. Permissions are debug INTERNET and the AndroidX signature-level dynamic-receiver permission; no sensitive or broad-storage permission was found. Evidence is in `apk-*.log`.
- Added documented official Drift tooling: pinned compatible drift_dev 2.35.1, temporary SQLite source creation, official dump under `drift_schemas/official`, generated helpers and SchemaVerifier tests. Official dump/generation: PASS.
- The first official verifier identified unquoted `key`/`value` identifiers that the schema parser could not read. Quoted those creation-SQL identifiers and regenerated the initial unreleased version 1 snapshots. This does not change table layout or invent an upgrade. Fresh creation/populated reopening and unexpected-table detection now pass. The APK's extracted debug kernel was checked for that corrected SQL (`apk-source-check.log`).
- Final formatting: PASS, 29 Dart files, zero changes. Final analysis: PASS, no issues, 51.2 seconds. Final complete suite: PASS, all 69 tests in 1 minute 34 seconds (`tests-final.log`).
- Final host-only 2,000-record/product search and visible-result render: 550.73 ms. This includes widget-test pumping/scrolling and excludes SQLite fixture setup; it is not an Android-device benchmark. Named-phone performance remains NOT RUN.
- Updated the README and phone checklist with actual artifact identity, minimum Android version, direct sideload steps and the three required fictional quote fixtures. Phone install/open, airplane-mode force-stop, Android system picker, TalkBack and manufacturer transfer checks remain NOT RUN by the owner's instruction.
- The owner subsequently authorized a source push to the verified empty public repository `https://github.com/Gabbu69/Presyo-M-lang.git`, branch `main`, after final checks. Source/tests/docs/lockfile will be published; APKs remain local ignored artifacts. Final Git commit/push evidence will be recorded separately.
