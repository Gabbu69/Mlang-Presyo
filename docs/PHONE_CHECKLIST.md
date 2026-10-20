# Owner phone checks

Current update: **0.2.0+3**, 18 October 2026 (Asia/Manila), named **PresyoGo**.
The previously authorized device was a **TECNO KL7 running Android 14**. At this
update's environment check, `adb devices -l` found no connected phone. Physical
checks for this update are **NOT RUN**, including live location and offline
restart. Record actual results separately in VERIFICATION.md when a device is
available; historical phone results do not establish a current pass.

Record the actual model, Android version, application ID, build hash, date and
result for each check. Keep device serials and authorization details out of the
published evidence. A host SQLite reopen test does not prove phone force-stop
behavior.

## Keep the personal notebook and test app separate

| Application | Application ID | Use |
|---|---|---|
| PresyoGo | `app.presyomlang.personal` | The owner's real notebook; preserve its existing records. |
| PresyoGo Tests | `app.presyomlang.personal.integration` | Automated fixtures and all fictional practice checks below. |

Before entering practice products, prices, lists or purchases, verify the
**PresyoGo Tests** label and the integration package identity. Never add
fictional test records to the personal application. Perform confirmed restore,
local reset and destructive practice checks only in the isolated Tests app.

The automated integration harness uses a test-owned temporary SQLite file and
cleans it after the test. For hands-on checks, use the ordinary `lib/main.dart`
entry point built with `PRESYO_INTEGRATION_TARGET=true`, and inspect its APK to
confirm the integration package and Tests label before installing it. This
provides an isolated, persistent practice notebook for the manual checklist.

## Install the handoff APK directly

Use the final inspected **0.2.0+3** personal APK identified in VERIFICATION.md and
verify its version-specific hash before copying it. Older artifact evidence is
baseline history and must not be presented as an inspected 0.2.0+3 build.

1. Before updating an existing installation, export a manual JSON backup from
   Settings and keep the file outside the app.
2. Copy the inspected APK to your phone using USB file transfer or another
   transfer method you choose. Flutter and USB debugging are not needed for
   this installation method.
3. Open the APK in the phone's Files app. If prompted, temporarily enable
   **Install unknown apps** for the specific Files/browser app opening the APK.
4. Choose Install, then Open **PresyoGo**. This is an internal development
   build signed for testing; owner-controlled public release signing is excluded.
5. Turn the install permission off again. Use the isolated **PresyoGo Tests**
   application for the fictional manual checks below.

If Android reports an incompatible update or signature, preserve the existing
notebook and its manual backup before considering uninstalling. Uninstalling may
remove the app's local records. The scripted update stops on failure and never
uninstalls the personal application. Record installation/opening only after the
actual result is observed.

## USB integration checks

1. Enable Developer options and USB debugging on the phone.
2. Connect by USB and approve the computer authorization prompt on the phone.
3. In the project PowerShell terminal run `. .\scripts\env.ps1`, then `adb devices`.
4. Run `.\scripts\test-phone.ps1`. It builds and verifies the isolated integration
   APK before invoking Flutter's device test runner. After the test, it resets
   the integration flag, rebuilds and verifies the normal personal APK, then
   updates and opens it for the current Android user.
5. If Windows does not recognize the device, install the phone manufacturer's
   appropriate USB driver. Do not accept unrelated driver/download offers.

Flutter's integration installer may uninstall an incompatible previous Tests
installation. Its package is separate from the personal notebook. The normal
application update uses direct `adb install --user <current-user> -r` and
requires successful command output as well as exit status. A failed update
stops without uninstalling the personal app. Export a manual backup before
updating any existing personal installation with records.

The native export stream helper has **7 local JVM tests passing**, with zero
failures, errors or skipped tests. This does not prove picker/provider behavior
on the phone. Use `review-native-tests.log` for that local result and record
actual Android picker checks separately.

## Offline shopping journey — Tests app only

- Enable airplane mode. Open **PresyoGo Tests**, verify its integration
  package identity, and choose Start empty in that isolated practice notebook.
- Add a specific practice product and two fictional stores inside Add price.
- Record three observations dated today: PHP45/500g loose, PHP85/1kg packaged,
  and PHP45/500g packaged. Confirm that the PHP85/1kg record has the lower unit
  price while each original package price and quantity remains visible.
- Create a shopping list with a PHP500 budget. Add a 750g item using the loose
  quote: PHP67.50. Select a 500g sealed PHP45 quote instead: two packs, PHP90,
  250g extra. Confirm Refresh estimate is explicit.
- Record an actual purchase with a different amount from its estimate. Cancel
  once before saving; cancellation must change nothing. Double-tap Save; one
  spending entry must exist.
- Force-stop **PresyoGo Tests** using Android app settings, reopen it, and
  verify the exact records, bought status and totals. Restore the phone's prior
  airplane-mode preference.
- Edit a price/product/category and confirm past purchase snapshots stay intact.
- Undo a purchase and confirm the linked item becomes Needed and spending drops.

## Portability and accessibility — Tests app only

- Save a JSON backup using the system destination picker. Success must appear
  after the checked native write, flush and close complete. Cancel a separate
  export and confirm that no success is shown and all practice records remain.
- Select a backup, cancel the replacement preview, and verify the original records.
- Test a confirmed restore with practice records and compare counts and totals.
- In the replacement preview choose Back up current first, then cancel that
  export. Replacement must stop and all existing practice records must remain.
  If the provider denies or fails a save, the app must show a recoverable error
  and must not confirm a backup or continue to replacement.
- Verify that an invalid backup with an incomplete selected-price snapshot is
  rejected before replacement. Retain a known-good practice backup.
- Exercise the 10 MiB complete-backup capacity boundary using isolated test
  fixtures. An oversized proposed change must fail before mutation, preserving
  the preceding notebook and its ability to export a complete backup.
- Export CSV, including practice text with a leading formula character; it must
  remain inert text when opened in a spreadsheet.
- Enable Android large text and TalkBack. Add a price and purchase with the
  keyboard open. Save, dates, errors, tab labels and quantity labels must be usable.
- Enter demo mode, confirm the persistent fictional-data banner on every route,
  and return to the Tests app's separate practice notebook. Demo records must
  not appear in that notebook's spending or the personal application.
- Check file-picker behavior and local reset with practice data only. Previously
  exported files must remain outside the reset's scope.
- A saved-but-refresh-needed screen must offer Retry loading and block further
  edits. Retrying a read must not replay a saved purchase, duplication or restore.
  Use the fault-injection host tests for deterministic read-failure evidence;
  record any additional phone reproduction separately.

## Preserved 0.1.0 baseline artifact

The previously inspected `dist/Presyo-Mlang-0.1.0-debug.apk` was version 0.1.0+1,
168,734,527 bytes (160.9187 MiB), with minimum Android 7.0/API 24 and arm64-v8a,
armeabi-v7a and x86_64 libraries. Its SHA-256 was
`2632f4921eacb54af009d36bf949d1461728697cdfd47c4bba19b57a7aa51022`.
Android Debug signing and 16 KiB alignment inspection passed for that file.
Physical installation/opening was NOT RUN at its original handoff because the
owner had deferred phone testing. Current 0.1.1 evidence is recorded separately.

## Evidence limits

Record actual results in VERIFICATION.md. Mark storage-full, manufacturer backup
transfer, TalkBack, airplane-mode, physical restart and performance checks NOT RUN
if they were not performed. The baseline inspected debug APK declares INTERNET
for Flutter's development VM service and the AndroidX signature-level
`app.presyomlang.personal.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
No sensitive or broad-storage permissions were found in that baseline file.
Inspect the final 0.2.0+3 personal and Tests APKs separately. The application has
no network client or upload SDK; record observed phone offline behavior in the
current verification results.


## Location and rename acceptance — 0.2.0+3, Tests app only

- Verify **PresyoGo Tests** and package `app.presyomlang.personal.integration`
  before using fictional records. Do not reset or restore the personal app.
- Start empty and verify no location prompt appears on launch, price entry or
  restarting. Home and Settings open Shopping area; All areas is the default.
- In Shopping area, tap Use my location. Test approximate then precise grants,
  denial, disabled providers and a timeout. Record each actual result separately.
  Retry, Enter area manually and All areas must remain usable after failure.
- Capture a position and inspect coordinates, accuracy, capture time and radius.
  Cancel before Save and verify the previous area remains. Save and restart;
  the saved center/radius must persist. Refresh location is another explicit tap.
- Tap location and immediately background the Tests app, including while a
  permission response is pending. Capture must cancel; returning to the app must
  not resume it automatically. Try again explicitly after returning. A queued
  request received while the Activity is stopped must not start a provider.
- Add a fictional store with a manual area. Capture a store GPS tag only through
  Tag this store with my current location, then Save. Cancel an edit/removal and
  verify the tag survives; save removal and verify it is cleared. Shopping area
  changes must not tag or move any store.
- Check Home recent prices, Prices, product history/comparisons and list estimate
  chooser show the same scope. Check different areas, radii and unlocated stores.
  Show all areas recovers excluded records without changing the saved area.
- In an empty area, verify Add store, Add price and Show all areas work. Existing
  lists and spending must stay visible and unchanged.
- In airplane mode, force-stop/reopen the Tests app; verify saved tags, prices,
  purchases, estimates and scope. A fresh GPS fix may be unavailable, but saved
  positions/manual areas/All areas must continue working. Restore airplane mode
  to its prior state when finished.
- With 200% text, keyboard and TalkBack, complete a location/store form and a price
  entry. Check no clipping, reachable Save, clear labels and announced errors.
- Export JSON/CSV through actual Android providers and check the location privacy
  notice. Import a legacy format 1 backup only in the Tests app; failed/canceled
  restore must leave its existing records intact.
- Record named phone, Android version, inspected APK hash, date, PASS/FAIL/NOT RUN
  for each case. Host tests cannot substitute for these observations.
