# Verification record — PresyoGo

Timezone: Asia/Manila. Application ID: `app.presyomlang.personal`.

## Current PresyoGo milestone — 18 October 2026, 0.2.0+3

Implements the approved location + rename plan: optional user-tapped phone
location, saved center/radius and manual areas; explicit store tags; scoped Home
prices, Prices, product comparison/history and list quote selection; safe All
areas recovery; visible PresyoGo branding with unchanged application identity.
Database schema 2 and backup format 2 retain v1 upgrade/import compatibility.

The schema export completed using the actual v2 database. Historical v1 fixtures
remain unchanged. Focused data checks passed except a test initially expecting a
direct SQLite exception from a background database; that test now checks Drift's
remote wrapper and the exact foreign-key error. Both migration tests passed on
rerun. Initial widget failures were test-host/selector synchronization issues and
are being corrected while preserving behavioral assertions.

| Check | Current result and evidence |
|---|---|
| Toolchain | PASS — Flutter 3.47.7 / Dart 3.13.5 / DevTools 2.60.0, project JDK 17.0.20.1+1; `presyogo-toolchain.log` |
| Schema generation and v1 preservation | PASS — actual v2 SQLite source, readable/official v2 snapshots and generated helpers; retained v1 snapshots/helper and dependency lockfile unchanged |
| Non-writing format check | PASS — 48 files, 0 changes; `presyogo-format.log` |
| Static analysis | PASS — no issues, 32.5 seconds; `presyogo-analyze.log` |
| Complete Flutter suite | PASS — 148/148, 2 minutes 41 seconds, exit 0; `presyogo-tests.log` |
| Android JVM / compiled release manifest | IN PROGRESS — `presyogo-native-tests.log` |
| 0.2.0+3 debug APK build / inspection | PENDING |

The final suite includes true v1-to-v2 migration/rollback, v2 creation/reopen and
foreign keys; old/new backups and location validation before restore; persistence
and frozen snapshots; integer-extreme regressions; 19 location widget flows and
14 channel cases; narrow/200% text, keyboard, touch targets and contrast checks.
Drift's debug warnings occur in tests deliberately opening independent database
connections, not a shared executor. Five fictional demo PNGs under
`docs/screenshots/` were generated and visually reviewed; they are host renders,
not phone screenshots. The earlier initial full run and format/analysis findings
are preserved in `presyogo-*-initial.log` and BUILD_LOG.md.

`adb devices -l` found no connected/authorized device. This update's physical
install/open, approximate/precise permission dialogs, live GPS/network fixes,
disabled providers, device cancellation/timeout, airplane-mode force-stop/restart,
TalkBack, actual file providers, storage-full and manufacturer transfer checks
are **NOT RUN**. Public release signing, distribution and pilot acceptance are
also not performed by this local milestone.

## Historical review update — 17 October 2026, 0.1.1+2

The review implements pending-save navigation/back protection, clearing hidden
manual estimates after quantity changes, parsed UTC list ordering, committed-write
reload recovery, full frozen-snapshot validation and aggregate row/UTF-8 backup
capacity checks. A small Android bridge confirms export only after checked write,
flush and close. The integration package is isolated from the personal notebook.
An initial phone run also exposed loss of the search field's text when its lazy
widget was disposed while the filter remained active. A parent-owned controller
now preserves the query and allows clearing it after recreation; the regression
proves actual EditableTextState disposal/recreation and retained query behavior.
Schema **1** and JSON backup format **1** are unchanged. Details and named
regressions are in `V1_REVIEW_2026-10-17.md`.

| Check | Current result and evidence |
|---|---|
| Initial review complete host run | FAIL, repaired — 89 passed / 3 restore-widget synchronization failures; `review-tests.log`. Bounded state waits preserve the cancellation, unchanged-data and no-replacement assertions. |
| Focused export/restore after synchronization repair | PASS — 7 tests; `review-platform-tests.log` |
| Host checks before the phone-discovered fix | PASS — 92 tests and analysis before the new search-retention correction; retained in `review-tests-before-phone-fix.log` and `review-analyze-before-phone-fix.log` |
| Final review static analysis after search fix | PASS — No issues found, 42.6 seconds; `review-analyze-final.log` |
| Final review complete Flutter suite after search fix | PASS — All 93 tests, 2 minutes 31 seconds; `review-tests-final.log` |
| Final formatting | PASS — 38 files, zero changes; `review-format-check.log` |
| Final review host 2,000-record search/render | PASS, host only — 852.434 ms. Includes widget pumping/scrolling and excludes SQLite fixture setup; no phone timing claim. |
| Native JVM stream-writer tests | PASS — 7 tests, zero failures/errors/skips; Gradle 7m45s, `review-native-tests.log` |
| Initial isolated APK package/installation | PASS — verified `app.presyomlang.personal.integration`; actual installation took 9.7 seconds. An uppercase Gradle flag mismatch was caught by the package guard before the first install and corrected. |
| First physical SQLite integration journey | PASS on TECNO KL7 — shopping/purchase state, SQLite close/reopen, backup round-trip and Home/Spending rendering; `review-phone-integration-first.log` |
| First physical 2,000-record search/filter run | FAIL — unique search/render measured 1581.394 ms, then clearing the recreated input left its old filter active. This is a failed full flow, not a phone performance pass. Bug fixed; assertions retained and a retained-query assertion added. |
| Corrected complete phone integration rerun | PENDING — an interrupted attempt had no final result; the resumed full run is not claimed passed until completion. |
| Updated normal APK | PENDING build, personal installation/open and version-specific output inspection |
| 0.1.1 artifact size/hash/signature/alignment/permissions | PENDING — the old 0.1.0 artifact below is not update evidence |
| Actual normal-app install/open and manual checks | AUTHORIZED / PENDING — TECNO KL7, Android 14/API 34, current user 0 |
| Updated source commit/push | PENDING final checks and verified Git evidence |

The phone was found authorized and without a Presyo installation for current
user 0 before this update's device checks. Other device users were not assessed.
Its availability supersedes the original deferral. No serial or debug-service
authentication URI is included in this record. Airplane-mode force-stop/reopen,
actual document picker/export/restore, TalkBack, physical storage-full behavior,
manufacturer transfer and successful complete named-phone performance checks
require observed results. See `PHONE_RESULTS_2026-10-17.md` for the separate
device record; the earlier SQLite pass does not imply the failed search test or
the pending corrected rerun passed.

## Historical 0.1.0+1 delivery — 16 October 2026

The sections below preserve the original delivery's evidence. Its earlier
phone-deferral statements and 69-test/0.1.0 APK results describe that baseline;
the current update's authorized device checks and pending publication are tracked
above.

## Observed automated results

| Check | Result | Evidence |
|---|---|---|
| Dependency resolution | PASS | `flutter pub get`, application `pubspec.lock` |
| Static analysis after style cleanup | PASS | `flutter analyze`: No issues found; `analyze.log` |
| SQLite schema export | PASS | 12 actual entities in `drift_schemas/schema_v1.json`; `schema-export.log` |
| Official Drift schema export/helpers | PASS | SQLite-file `drift_dev schema dump` and `schema generate`; `schema-official-export-final.log`; official snapshot in `drift_schemas/official` |
| Official Drift SchemaVerifier tests | PASS | Fresh actual v1 creation, populated reopen and unexpected-table rejection; final complete suite |
| Domain/data tests | PASS | 50 tests; `tests-core.log` and core portion of `tests-all.log` |
| UI/regression/render tests after fixes | PASS | 16 tests; `tests-widgets.log` |
| Original full-suite attempt | FAIL, repaired | 60 passed / 6 failed; `tests-all.log`. Failures were test interaction with lazy scrolling and a synchronous fault fixture. Corrected scrolling and controlled the in-flight write, preserving the assertions. All 16 UI tests subsequently passed. |
| Final formatting | PASS | 29 Dart files, zero changes; `format-final.log` |
| Final static analysis | PASS | No issues found, 51.2 seconds; `analyze-final.log` |
| Final complete suite | PASS | All 69 tests in one run, 1 minute 34 seconds; `tests-final.log` |
| Host 2,000-record search/render | PASS, host only | Unique search and visible result render: 550.73 ms; `HOST_WIDGET_SEARCH_ONLY` in `tests-final.log`. Includes widget pumping/scrolling, excludes SQLite fixture setup; not phone performance. |
| Android development APK | PASS | Successful `flutter build apk --debug --verbose`, 1 hour 54 minutes 20 seconds including cold-cache/download work; output inspected and handoff copy verified; `apk-build-verbose.log` and `apk-*.log` |

Drift warns in debug tests that multiple instances of the same database class
exist. These fixtures intentionally use separate SQLite connections/files for
round-trip and isolation tests; no QueryExecutor is shared. The app closes the
selected database before switching modes. The warning was not suppressed.

## Inspected APK

| Detail | Observed result |
|---|---|
| Handoff file | `dist/Presyo-Mlang-0.1.0-debug.apk` |
| Application/version | `app.presyomlang.personal`, version 0.1.0+1 |
| Size | 168,734,527 bytes / 160.9187 MiB |
| SHA-256 | `2632f4921eacb54af009d36bf949d1461728697cdfd47c4bba19b57a7aa51022` |
| Android compatibility | Minimum API 24 / Android 7.0; target API 36 |
| Native architectures | arm64-v8a, armeabi-v7a, x86_64 |
| Certificate | Android Debug, APK Signature Scheme v2 verification PASS; `apk-signature.log` |
| ZIP/native alignment | 16 KiB alignment verification PASS; `apk-alignment.log` |
| Compiled backup rules | `allowBackup=false`, cloud/device-transfer exclusions present; `apk-manifest.log`, `apk-backup-rules.log`, `apk-data-extraction-rules.log` |
| Permissions | INTERNET for the Flutter debug VM and AndroidX signature-level `app.presyomlang.personal.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; no sensitive/broad-storage permission; `apk-permissions.log` |
| Final SQL source in artifact | Extracted debug kernel contains corrected quoted `key`/`value` SQL; `apk-source-check.log` |

This is an internal development APK, signed with an Android Debug certificate.
It has not been installed or opened on a physical phone during this build.
Compiled exclusions do not prove every manufacturer's device-transfer behavior.
The binary is a local ignored artifact, separate from the authorized GitHub source
publication. AGP/Kotlin compatibility deprecation warnings remain in the build log.

## Acceptance checklist

PASS below means the named automated/source check passed. It does not imply an
Android phone was tested. The owner explicitly chose to test the phone later.

| Kit case | Result and boundary |
|---|---|
| T01 exact money | PASS — exact parsing, formatting and sums |
| T02 invalid input | PASS — invalid signs, exponents, non-finite/oversized input, zero/null distinctions |
| T03 canonical units | PASS — measured conversion and incompatible-unit rejection |
| T04 rounding once | PASS — final half-up rational rounding |
| T05 unit comparison | PASS — exact normalized values and ordering |
| T06 whole packs | PASS — package ceiling, loose total and extra quantity |
| T07 like for like | PASS — product identity/measurement boundaries |
| T08 latest record | PASS — latest offer and deterministic same-day tie breaking |
| T09 freshness | PASS — age seven/eight boundary |
| T10 no recent records | PASS — stale opt-in, dates retained, future dates rejected |
| T11 timezone | PASS — injected Manila midnight boundary |
| T12 promotion/precision | PASS — default exclusions and exact fraction ranking |
| T13 complete projection | PASS — 500/165/310 budget example |
| T14 incomplete projection | PASS — missing counts, null balance, skipped exclusion |
| T15 explicit bought | PASS — cancel, duplicate UI taps, concurrent repository callbacks |
| T16 undo/failure | PASS — atomic save/undo rollback and zero budget |
| T17 historical integrity | PASS — quote deletion/edits and catalog snapshots |
| T18 monthly boundary | PASS — purchase date and snapshot category grouping |
| T19 estimate editing | PASS — manual clearing/reconfirmation and frozen-price recalculation |
| T20 duplicate/archive | PASS — new IDs, reset states/estimates, retained spending |
| T21 offline restart | PARTIAL — host SQLite close/reopen PASS; Android airplane-mode and force-stop NOT RUN |
| T22 referential integrity | PASS — foreign keys, integer CHECKs, archive behavior, immutable referenced quantity kind |
| T23 migration | No preceding released schema exists. Official Drift dump/helper generation and SchemaVerifier initial-v1 creation/populated-reopen checks PASS, alongside foreign-key and nondestructive future-version refusal tests. A real upgrade migration is NOT RUN and required when schema changes. |
| T24 backup round trip | PASS — all entity groups, Unicode, archived rows, null/zero budgets and snapshots |
| T25 restore validation | PASS — invalid JSON/version/IDs/enums/ranges/references/size/count rejected |
| T26 restore transaction | PASS — halfway/before-commit faults preserve old logical records |
| T27 CSV safety | PASS — leading formula/control characters, quoting, Unicode and integer money columns |
| T28 export boundary | PARTIAL — privacy/cancellation/cleanup paths implemented; actual Android picker/export cancellation NOT RUN |
| T29 demo isolation | PASS — separate repository databases/reset/seed and route banner tests; actual phone mode switching NOT RUN |
| T30 permissions/network | PASS for compiled debug APK inspection — INTERNET is development VM support; AndroidX dynamic-receiver permission is signature-level. No sensitive/broad-storage permissions or app network client/upload SDK. Physical offline workflow remains NOT RUN. |
| T31 backup policy | PARTIAL — compiled allowBackup=false and legacy/modern cloud/device-transfer exclusions inspected; actual manufacturer transfer NOT RUN |
| T32 local reset | PASS — all eight groups clear, explicit UI confirmation, onboarding reusable; external files are outside repository reset |
| T33 accessibility | PARTIAL — 320px/200% text, keyboard-visible Save, semantics and primary contrast checks PASS; physical TalkBack NOT RUN |
| T34 error recovery | PASS for injected database/form failures and retry; physical storage-full condition NOT RUN |
| T35 build evidence | PASS for actual APK build/output/hash/signature/alignment inspection and all 69 host tests; physical install/open NOT RUN by owner choice |
| T36 signing/scope | PASS — Android Debug certificate verified and development build labeled. Public release signing/Play Store publication excluded; the owner separately authorized GitHub source publication. |

## Rendered visual review

`screenshots/home_demo_390.png`, `prices_demo_390.png`,
`spending_demo_390.png`, `list_demo_390.png` and
`home_demo_320_text200.png` are **Flutter widget-test renders** with fictional
fixtures. They are not screenshots from an Android phone. Text and Material icons
are loaded only for the QA render; the app uses system fonts and its bundled
Material icon asset. Visual inspection checked readable labels, visible fictional
data banner, figures, spacing, wrapping and navigation. At large text sizes the
decorative Home introduction is omitted so actions and shopping data appear first.

## Source publication

The owner explicitly authorized pushing source, tests, documentation and the
application lockfile to [Gabbu69/Presyo-M-lang](https://github.com/Gabbu69/Presyo-M-lang)
on `main`. The implementation was published successfully at
[`11be9ef1b7061542188b2e11feff9fe98b8a31d2`](https://github.com/Gabbu69/Presyo-M-lang/commit/11be9ef1b7061542188b2e11feff9fe98b8a31d2).
`git push --set-upstream origin main` passed; `git ls-remote` and GitHub's commit
API both returned that exact SHA. A following documentation commit records this
observed result; the final handoff identifies the final remote revision. The
Gradle wrapper scripts/JAR are included in source, with the distribution checksum
pinned. APK distribution, release signing and Play Store publication have not
been performed. The inspected APK is a local handoff artifact under `dist/`.

## Explicitly not run

- Physical APK installation/open, airplane-mode force-stop/restart and device performance.
- Actual system file-picker/share interactions on Android.
- TalkBack interaction on a phone and physical storage-full behavior.
- Cloud/device-transfer restoration tests on any manufacturer device.
- 2,000-record performance measurements on a named pilot phone.
- Public release signing, Play Store publication, community edition or pilot acceptance.

Use `PHONE_CHECKLIST.md` and `scripts/test-phone.ps1` for the owner's later checks.
No physical-device result is inferred from host tests, source review or an APK build.
