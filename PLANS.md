# Implementation roadmap

## Current status — 16 October 2026

| Milestone | Current evidence |
|---|---|
| M0 | COMPLETE — project preserved; Flutter/Dart, Java17 and Android API36/build-tools/NDK installed on G; versions and diagnostics recorded. Doctor warnings and owner-deferred phone checks are documented. |
| M1 | IMPLEMENTED / HOST VERIFIED — navigation, theme, local SQLite repositories and exact helpers; domain tests and analysis pass. |
| M2 | IMPLEMENTED / HOST VERIFIED — price/catalog forms, validation, failed-save recovery and inline-creation regression tests pass; host SQLite reopen passes. Android force-stop remains deferred. |
| M3 | IMPLEMENTED / HOST VERIFIED — comparison, dates, history, explicit older opt-in and package estimation tests pass. |
| M4 | IMPLEMENTED / HOST VERIFIED — lists, frozen estimates, explicit purchases, spending, snapshots, duplication and transaction/idempotency tests pass. |
| M5 | IMPLEMENTED / HOST VERIFIED — backup validation/round-trip/rollback, CSV safety, local reset, demo isolation, narrow/large-text/keyboard tests pass. Android picker/TalkBack/transfer checks remain deferred. |
| M6 | HOST BUILD / VERIFICATION COMPLETE — 29-file formatting and analysis pass; all 69 tests pass. Development APK built, copied and inspected for metadata/hash/signature/alignment/permissions/backup rules. Physical-phone install/open, offline restart and device acceptance remain owner-deferred NOT RUN. |

See `docs/VERIFICATION.md`, `docs/BUILD_LOG.md` and command logs for exact evidence.
Physical-phone testing was explicitly deferred by the owner, who requested the
APK first. No device/pilot/public-release completion is inferred from host checks.
The later owner-authorized GitHub source push targets `main` at
`https://github.com/Gabbu69/Presyo-M-lang.git` after the final checks. The APK stays
local and ignored; source publication does not complete physical-device acceptance.

The original milestone instructions below are retained as the acceptance roadmap.

Use `AGENTS.md` for development rules, `PRODUCT_SPEC.md` for behavior, and `ACCEPTANCE_TESTS.md` for test cases. Version 2 is excluded from these milestones.

## M0 - Inspect and establish the environment

Inspect the current project and Git state before writing. Check applicable instructions. Identify OS/shell, Flutter and Dart versions, Java, Android SDK, available device/emulator, and existing source/dependencies.

Useful diagnostics, when installed:

```text
flutter --version
flutter doctor -v
flutter devices
java -version
```

Do not assume shell-specific commands or paths. Do not reinstall tools, change machine-wide versions, accept licenses on the owner's behalf, or recreate an existing app without appropriate approval. If tools are absent, report exact missing prerequisites and continue only work that can be done honestly.

Create `docs/DECISIONS.md`, `docs/ENVIRONMENT.md`, and `docs/BUILD_LOG.md` with observed facts. Select compatible stable dependencies. Preserve this kit when scaffolding.

**Gate:** environment and blockers documented; application scope remains Android; no user files lost. A missing compiler may block running/building but should not be mislabeled as a successful test.

## M1 - Foundation and pure domain helpers

Create or extend the Flutter app, four-tab shell, simple theme, and empty states. Set up Drift/SQLite, repositories, and Riverpod state. Keep Settings accessible from the app bar. Establish migration schema snapshots and foreign-key checks.

Implement and test exact money parsing/formatting, supported quantity conversion, final-boundary rounding, and an injectable Asia/Manila date helper. Keep demo and real database paths separate from the start if demo mode is included.

**Gate:** no invented live data; shell launches where testing is possible; persistence opens safely; core arithmetic tests pass. Do not build all future screens as static mockups.

## M2 - First complete feature: record a price

Implement product/store creation, validation, price-entry form, price list, and edit/delete/archive behavior. Inline product/store creation should return to the price form without losing values. Persist records through repositories and reload after app restart.

Source labels are personal provenance, not verification. Every record shows original quantity and observed date. Preserve state on failed saves. Include duplicate-submit protection.

**Gate:** create a real record offline, restart, and retrieve the exact saved record. Invalid quantity/date/money is rejected. Empty state, error state, and canceled form are tested.

## M3 - Trustworthy comparisons and history

Implement product detail, latest-offer selection, same-variant comparisons, normalized values, age labels, seven-day default filtering, older-record opt-in, and exclusion of promotional/conditional prices from default ranking.

Test before adding a best-value badge. Show original package price alongside unit price. Implement loose-versus-whole-package estimation as pure domain functions. No basket optimizer or claimed real-time availability.

**Gate:** comparison and freshness cases pass; an older cheaper record cannot outrank a newer record for the same store/offer; unknown unit conversions cannot slip through.

## M4 - Lists, purchases, and actual spending

Implement list CRUD/archive/duplicate, quantities, optional budgets, manual or selected-price estimates, snapshots, Needed/Bought/Skipped states, and explicit actual-purchase confirmation.

Implement a purchase ledger, unique link per list item, atomic save/undo, standalone purchases, monthly grocery spending, category totals, and the Home summary. Incomplete estimates remain visibly incomplete.

**Gate:** a full shopping journey works; duplicate taps produce one expense; editing a saved quote cannot rewrite actual spending; list and monthly figures are calculated from the same ledger without double-counting.

## M5 - Data safety, portability, and usability

Implement consistent JSON backups, replace-only validated restore, prices/purchases CSV exports, formula-safe text escaping, privacy copy, confirmed local reset, and temporary-export cleanup. Review Android cloud backup and data-transfer rules and release permissions.

Finish onboarding, manage products/stores, optional isolated demo mode, screen-reader labels, large text, keyboard handling, and usable narrow-phone layouts. Do not add another language unless reviewed translations are supplied.

**Gate:** backup/restore and rollback cases pass; cancellation is safe; exports warn about unencrypted private data; all ordinary functions work offline; demo information cannot contaminate real records.

## M6 - Integration checks and pilot APK

Run the complete relevant test suite, analyze code, verify formatting, inspect dependencies/permissions, and review the actual Android build configuration. Test process restart and at least one migration path. Record device and OS details for manual tests.

Use the installed toolchain's supported commands. Typical commands include:

```text
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d <actual-device-id>
flutter build apk --debug
```

Only run code generation when configured; inspect conflicts before generated-file cleanup. Omit nonexistent paths rather than claiming a formatting failure is an application defect. Do not paste a placeholder device ID literally.

Create a verified internal development APK when possible. A public release is a separate gate requiring owner-approved application ID and signing configuration. With these configured, the relevant commands may include:

```text
flutter build apk --release
flutter build appbundle --release
```

Never claim release signing is correct merely because a release-mode build succeeds; inspect whether the build still uses the debug signing configuration. Inspect the actual output files and preserve owner-controlled signing credentials outside Git.

**Gate:** checks have concrete PASS/FAIL/NOT RUN statuses; known issues documented; app actually exercised on Android; artifact path verified. No automatic public distribution.

## Ongoing verification record

After each milestone append the date, environment, changed files, commands, exit statuses, meaningful test results, unrun checks, remaining issues, and the next milestone. Distinguish implementation-complete from verified-on-device.

Do not mark later milestones done because earlier screens look polished. Fix calculation, restore, migration, and privacy failures before cosmetic extras.
