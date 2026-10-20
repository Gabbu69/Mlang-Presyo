# Implementation decisions

## PresyoGo location and rename milestone — 18 October 2026, 0.2.0+3

- The owner approved the name **PresyoGo** and tagline **Your prices, wherever
  you shop.** This supersedes the earlier choice to retain the M'lang brand.
  Coverage is anywhere in the Philippines, with PHP and Asia/Manila dates.
- Location only filters the owner's saved records. Check it once after a button
  tap; accept approximate grants and keep manual/All areas fallback. Do not
  request it at startup, follow travel continuously, or infer municipality names.
- Preview a phone fix before Save. Default nearby radius is 10 km, with 5/25 km
  alternatives. Show capture time/accuracy and an explicit Refresh location.
  Canceling a draft or failing capture/write retains the previous saved scope.
- Home recent prices, Prices, product comparisons/history and estimate quote
  selection share the same area matching. Screen-local Show all areas overrides
  do not overwrite settings. Shopping lists and the ledger stay accessible across
  places; a scope change never refreshes a frozen estimate or rewrites history.
- Store tagging is an independent explicit action saved with the store form.
  New shopping areas never relocate existing stores. Unlocated stores are
  excluded from nearby matching with a visible All areas recovery route.
- Preserve application IDs, namespace, Dart package/imports, channel identifiers,
  signing identity, personal/demo database paths and mode marker. Rename visible
  labels to PresyoGo/PresyoGo Tests and new export filenames to presyogo_.
- Schema 2 and outer backup format 2 are location upgrades, independent of the
  branding. Keep v1 schema fixtures and support genuine format 1 imports. Existing
  frozen snapshot format 1 remains valid. Exports warn about unencrypted tags.
- Retain dependencies and existing G: toolchain/caches. Saved area shortcuts,
  favorite stores and backup reminders are deferred suggestions. Public build
  distribution and remote infrastructure are outside this local milestone.
- Native location remembers Activity onStart/onStop state. A queued channel call
  or late permission continuation received while stopped is canceled before
  requesting providers; returning to the Activity never resumes capture itself.
- At inspection, `adb devices -l` reported no connected device. Host verification
  and artifact inspection can proceed; phone acceptance requires current evidence.

## Owner-authorized multi-place update — 0.2.0+3

- On 17 October 2026 the owner required operation outside M'lang and explicitly
  selected optional phone GPS with a manual area fallback. This authorization
  supersedes the earlier GPS exclusion; it does not authorize online price
  feeds, maps, background tracking or community services.
- Retain the established Presyo M'lang brand and internal application ID, while
  removing geographic restrictions from product copy. PHP and Manila date rules
  remain in use. GPS coordinates do not establish a detected city name; area
  labels are entered by the user.
- Default location scope is All areas. Manual area labels and nearby radii are
  optional, saved choices. GPS is requested only by a user action, once per
  request, with a bounded acquisition time. Denial or unavailability leaves the
  manual workflow usable. Store GPS tagging requires a separate explicit action.
- Schema 2 adds nullable store location fields and a real, tested version 1
  upgrade. Logical backup format 2 is separate; version 1 imports receive null
  location defaults. Existing ledger and estimate snapshots are preserved.
- The superseded 0.1.1 normal build was intentionally stopped before new source
  edits. The isolated 0.1.1 practice app remains useful for core manual checks;
  final handoff requires a new 0.2.0 artifact and device verification.

Current review: 17 October 2026 (Asia/Manila), version 0.1.1+2 internal Android pilot.

## Version 0.1.1 review decisions

- The owner authorized review and fixes for remaining V1 issues. The application version advances to 0.1.1+2; SQLite schema version 1 and logical JSON format version 1 remain separate and unchanged.
- A committed write followed by a failed reload must not be presented as an unsaved action. The controller retains the previous readable snapshot while child routes return to the shell, blocks further writes, and displays a saved-but-refresh-needed state. Retry reloads the notebook without replaying the action; a successful read clears the block. A failed transaction retains normal form retry behavior.
- Repository mutations are gated by the size of the complete canonical JSON backup. A proposed change that would exceed 10 MiB UTF-8 is rejected before mutation, keeping the notebook exportable. Capacity validation reserves the longest supported UTC export timestamp. The existing 20,000-total-row limit includes settings and monthly budgets.
- Selected-price snapshots require the complete version 1 basis: quote, offered quantity, selling mode, observation date, product ID/name/brand/variant/category/quantity kind, store ID/name, offer type, and source type. Restore rejects missing or malformed snapshot fields before replacement. A detached source-price reference retains its complete frozen basis.
- Search text belongs to the Prices page state, with a parent-owned controller disposed when the page closes. Scrolling an unfocused input out of a lazy list must not discard the visible query while leaving its filter active. A regression explicitly exercises input disposal/recreation and clearing the query.
- Android export uses an app-owned `ACTION_CREATE_DOCUMENT` MethodChannel bridge. Success follows a non-null writable stream, completed write, flush, and close. Work runs off the UI thread; cancellation returns no success. Picker, permission, stream, and activity-lifecycle failures complete with a generic error, without private URIs or contents in logs. A failed or canceled “Back up current first” stops the restore flow. FilePicker remains the backup-selection interface, and app-owned temporary import copies are cleaned after the operation.
- The checked native stream writer has seven passing local JVM tests: successful write/flush/close ordering, null provider stream, permission denial, write failure, flush failure, close failure, and preservation of an original write failure when close also fails. Evidence is `review-native-tests.log` and the Gradle test XML; this verifies stream handling independently of a phone document provider.
- Integration builds use `PRESYO_INTEGRATION_TARGET=true`, application ID `app.presyomlang.personal.integration`, and the visible label **Presyo M’lang Tests**. The property and its environment-variable suffix are uppercase because Dart uppercases Windows environment names. The ordinary personal app retains `app.presyomlang.personal` and **Presyo M’lang**. Test fixtures and hands-on fictional practice belong only in the isolated Tests app.
- `scripts/test-phone.ps1` builds and inspects the integration package before Flutter can install it. This isolates Flutter's uninstall-and-retry behavior from the personal notebook. The script resets the integration flag before the normal build, verifies the normal package identity, and updates it only through direct `adb install --user <current-user> -r`. It does not uninstall the personal app, and requires successful install and launch output as well as exit status. The caller's prior Gradle flag is restored on exit.
- The earlier phone deferral has been superseded: the owner made a **TECNO KL7 running Android 14** available for authorized testing. The 0.1.1 phone run and final APK inspection/hash are pending at this documentation update. Actual device results must be recorded separately from the passing native JVM tests and prior host results.

## Version 0.1.0 baseline decisions

Recorded 16 October 2026 (Asia/Manila). The following preserves the original pilot decisions and evidence boundaries.

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
- At the baseline handoff, physical-phone testing was deferred by the owner's instruction. APK compilation and host verification continued independently. That deferral is superseded by the current review decision above; the baseline phone result remains NOT RUN.

See BUILD_LOG.md and VERIFICATION.md for the successful baseline APK inspection, baseline 69-test host result, and the separately recorded 0.1.1 checks. Build verification, source publication and physical-phone acceptance are separate evidence boundaries.
