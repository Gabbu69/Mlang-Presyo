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

## Verified source publication

- Owner-authorized `git push --set-upstream origin main`: PASS to `https://github.com/Gabbu69/Presyo-M-lang.git`.
- Implementation commit: `11be9ef1b7061542188b2e11feff9fe98b8a31d2`. Both `git ls-remote origin refs/heads/main` and GitHub's commit API returned that exact SHA after the push.
- Included source, tests, documentation, application lockfile and generated Gradle wrapper scripts/JAR. No APK, database, cache, export or signing keystore was tracked.
- This following documentation commit records the observed publication. Final remote revision and the source-archive identity are verified separately in the local handoff metadata and final report. Runtime code and the inspected APK are unchanged.

## V1 follow-up review — 17 October 2026

- Owner requested a remaining-issues review and then connected an authorized TECNO KL7, Android 14 / API 34. The earlier phone-test deferral no longer applies. No Presyo application was installed for the current Android user when first inspected. Device serials are excluded from the repository.
- Updated the internal version to 0.1.1+2. Database schema 1 and logical backup format 1 remain unchanged; no production migration was invented.
- Fixed route changes during pending saves, manual estimates surviving hidden-mode quantity edits, chronological list ordering, and replay risks after a committed write whose read-back fails. Read recovery now blocks further writes and retries only the read.
- Enforced aggregate row and serialized 10 MiB capacity on settings/budgets and other writes, and required complete frozen estimate snapshots. Existing records are retained when a write would exceed portability limits.
- Replaced export saving with an app-owned Android document writer that confirms success only after write, flush and close. Cancellation and permission/I/O errors complete without permitting a dependent replacement restore.
- The first updated Flutter suite had 89 passes and three restore-widget synchronization failures. Bounded state waits repaired the test synchronization without weakening cancellation, confirmation, or unchanged-data assertions. Focused export/restore tests subsequently passed all seven cases.
- Before the phone-found search fix, formatting passed for 37 files with zero changes. `flutter analyze`: PASS, no issues, 38.8 seconds (`review-analyze-before-phone-fix.log`). The complete `flutter test --concurrency=1 --reporter expanded` passed all 92 tests in 2 minutes 15 seconds (`review-tests-before-phone-fix.log`).
- `:app:testDebugUnitTest --tests app.presyomlang.personal.CheckedExportWriterTest -PpresyoIntegrationTarget=false`: PASS, Gradle build 7 minutes 45 seconds. JUnit XML reports seven tests, zero failures/errors/skips, covering null streams, permission denial, successful close order and write/flush/close failures (`review-native-tests.log`).
- Hardened phone testing: build/inspect the isolated `app.presyomlang.personal.integration` package before allowing Flutter's installer to run; label it Presyo M’lang Tests. Rebuild and inspect the normal package, then use direct current-user ADB update and confirmed launch. The script never uninstalls the personal notebook after an incompatible update.
- Physical-device integration, the updated APK inspection and publication are in progress. Their final results will be appended from observed output.
- First isolated phone build compiled successfully (472 seconds), but the required pre-install identity check rejected it: Dart uppercased the Windows environment name, so Gradle did not receive the mixed-case test flag and the APK retained the normal ID. No installation was attempted. Changed the property/environment suffix to uppercase `PRESYO_INTEGRATION_TARGET`, added explicit build arguments, and selected the current Android user for Flutter's test runner. The identity guard remains mandatory on retry.
- Corrected isolated package build: PASS, 280.1 seconds; AAPT verified `app.presyomlang.personal.integration` before installation (`review-integration-apk-badging.log`). The Flutter runner's device-specific build completed in 507.9 seconds and installed in 9.7 seconds. On TECNO KL7, the SQLite shopping/purchase/reopen/backup journey passed. The 2,000-record test found and rendered its unique result in 1581.394 ms, then failed its clear-search assertion: expected all 2,000 results, observed one. This is not recorded as an overall performance-test pass (`review-phone-integration-first.log`).
- Device failure exposed real lazy-list state loss: scrolling the unfocused search field out of the viewport discarded its internal controller while the Prices page retained the filter. A parent-owned controller and a focused scroll/clear regression are being added; the phone assertion remains unchanged.
- Search fix complete. The new host regression explicitly proves the original unfocused input was disposed, then requires the query to reappear and clearing to restore every result. All existing integration counts are retained, with an additional retained-query assertion. Final formatting: PASS, 38 files, zero changes. Final analysis: PASS, no issues, 42.6 seconds. Final full host suite: PASS, all 93 tests in 2 minutes 31 seconds (`review-format-check.log`, `review-analyze-final.log`, `review-tests-final.log`). The phone integration suite is being rebuilt and rerun in the already-verified isolated package.
- The interrupted afternoon phone rebuild had no final result and its process was no longer running at evening continuation. Device authorization was rechecked before restarting. The resumed build then failed before running tests: Windows was at 97% committed memory and Dart could not start a worker thread (`review-phone-build-resource-failure.log`). Cleared only the failed task's verified orphan compiler/Gradle processes; available RAM recovered to about 1.2 GiB. Reduced project Gradle heap to 768 MiB, metaspace 384 MiB, code cache 96 MiB and active processors to two; the retry is session-limited to two processors as well. No system Java or page-file configuration changed.
- Lower-memory Android compilation and installation passed (526.1 seconds build, 12.4 seconds install). The test runner then failed during its five-second VM-service connection stage, before tests executed (`review-phone-debug-timeout.log`). Device remained unlocked, process running, no Android crash observed. The app-specific startup log showed an available VM service. Retrying with the optional Dart Development Service disabled and a fresh isolated-app launch; no application assertion was changed.
- The owner closed unused applications after another observed Windows allocation failure. The no-DDS build/install completed (652.9 seconds / 9.9 seconds). The SQLite integration journey passed again. The new explicit retained-query assertion passed on-device, confirming the lazy-field fix; the following automated empty-text input still left one result instead of 2,000. The run also reported a Flutter VM custom golden-stream error without DDS. Neither issue is hidden or counted as a complete integration pass (`review-phone-input-rerun.log`). Investigating platform input synchronization while building the ordinary UI in the isolated package for direct manual checks.
- Installed SDK source explains the remaining injected-input failure: physical IntegrationTestBinding does not register the TestTextInput stub. After unfocusing, the binding retains the same EditableTextState while the real text-input connection is closed; WidgetTester.showKeyboard skips requesting that same cached state, so subsequent injected edits have no current connection and are ignored. The helper now explicitly requests the keyboard, pumps, enters text and asserts the controller value before and after unfocus. Initial and subsequent searches use it. All result counts, retained-query and filter assertions remain intact; production code is unchanged by this test-driver repair. Final retry will use DDS again because disabling it exposed an unsupported custom VM stream.

## PresyoGo location + rename — 18 October 2026, 0.2.0+3

- Implemented the owner-approved Philippines/PHP/Manila scope with optional tapped
  phone location, manual areas and default All areas. Saved locations remain drafts
  until Save; cancellation/failure preserves previous scope. Nearby radii are
  5/10/25 km, default 10 km, with visible original capture time and accuracy.
- Connected Home's shopping-area card/Settings and scoped recent prices, browsing,
  comparisons/history and list offer selection. Each surface has local All areas
  recovery. Empty areas offer Add store, Add price and tag-existing-store actions.
  Lists/actual spending and frozen purchase/estimate snapshots stay independent.
- Added explicit store capture/remove, with failed recapture preserving its tag.
  GPS never infers city names or assigns all stores the shopper's saved center.
- Renamed visible copy and Android labels to PresyoGo / PresyoGo Tests, tagline
  Your prices, wherever you shop. Internal package/channel IDs, data filenames,
  mode marker and signing identity are retained. New export names use presyogo_.
- Completed schema2 exports and genuine populated v1 migration coverage, format1
  import/format2 round-trip and whole-document validation/rollback tests. Historical
  v1 fixtures remain unchanged. Inner frozen snapshot version1 is intentional.
- Review found two defensive abs-overflow bounds (minimum signed integer). Replaced
  with signed bounds; regressions require invalid coordinates/settings be rejected
  and failed writes/restore leave the notebook unchanged.
- Native capture now checks all eligible GPS/network caches and takes the newest
  valid fix, then listens to permitted enabled providers in one 20-second acquisition.
  Failures of one provider do not hide another; terminal paths clean listeners.
- No dependencies were added or upgraded; pubspec.lock is unchanged. Kept G: tools
  and serialized SDK/Gradle work under current RAM constraints. No system settings,
  remote infrastructure, release signing or APK distribution were changed.
- Files completed/updated for this milestone: lib/core/location.dart;
  lib/app/{english,strings}.dart; lib/features/{location,catalog,home,prices,lists,
  settings}.dart; lib/platform/location_service.dart; lib/data/{portability,
  validation}.dart; AndroidLocation.kt, LocationFixPolicy.kt and its native tests;
  MainActivity.kt; integration_test/app_test.dart; new domain/data/migration/widget/platform tests;
  retained v1 plus generated v2 Drift schema/helpers; scripts/{export-schema,
  build-debug,inspect-apk}.ps1; Android visible-label build configuration; AGENTS,
  PRODUCT_SPEC, ACCEPTANCE_TESTS, PLANS, README and current docs. Pre-existing
  review and schema2/repository changes were preserved.
- Initial non-writing format check found the unfinished location bridge needed
  formatting; formatted that file and final check reports 48 files / 0 changes.
  Initial analysis found two brace infos and an intentionally experimental Drift
  remote import in a test; braces fixed and the typed pinned-library assertion
  retained with a documented narrow import ignore. Final analysis reports no issues.
- The first full suite had 147 passes / 1 onboarding-test failure. At 200% text, lazy
  scrolling to Start empty did not also mount Try fictional demo after the shorter
  tagline. The test now reveals both actions independently, preserves both
  existence assertions and additionally requires each action be tappable. No
  product behavior changed. The complete corrected suite is being rerun.
- Focused location verification: 33/33 (19 widget / 14 channel) passed. Both actual
  old-to-new migration tests passed. Final full suite/native/build evidence is
  recorded in the current section of VERIFICATION.md when commands complete.
- `adb devices -l` found no connected phone. New physical GPS/permission dialogs,
  airplane-mode restart, installation, TalkBack, system export provider, physical
  storage-full, manufacturer transfer and pilot acceptance checks are NOT RUN.
