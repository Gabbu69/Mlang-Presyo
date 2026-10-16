# Owner phone checks

Use the internal development APK on an authorized Android phone. Record the
actual model, Android version, build hash, date and result for each item below.
An automated host SQLite reopen test does not prove phone force-stop behavior.

## Install the handoff APK directly

The inspected artifact is `dist/Presyo-Mlang-0.1.0-debug.apk` in the project:
version 0.1.0+1, 168,734,527 bytes (160.9187 MiB), Android 7.0/API 24 or newer,
with arm64-v8a, armeabi-v7a and x86_64 libraries. Its SHA-256 is
`2632f4921eacb54af009d36bf949d1461728697cdfd47c4bba19b57a7aa51022`.
The Android Debug certificate and 16 KiB alignment checks passed. These build
checks do not establish compatibility with your particular phone until tested.

1. Before updating an existing installation, export a manual JSON backup from
   Settings and keep the file outside the app.
2. Copy the inspected APK to your phone using USB file transfer or another
   transfer method you choose. Flutter and USB debugging are not needed for
   this installation method.
3. Open the APK in the phone's Files app. If prompted, temporarily enable
   **Install unknown apps** for the specific Files/browser app opening the APK.
4. Choose Install, then Open **Presyo M’lang**. This is an internal development
   build signed for testing; owner-controlled public release signing is excluded.
5. Turn the install permission off again and perform the manual checks below.

If Android reports an incompatible update or signature, preserve the existing
notebook and its manual backup before considering uninstalling. Uninstalling may
remove the app's local records. Direct installation/opening has **NOT RUN** status
until you perform it and record the actual device result.

## Optional USB integration checks

1. Enable Developer options and USB debugging on the phone.
2. Connect by USB and approve the computer authorization prompt on the phone.
3. In the project PowerShell terminal run `. .\scripts\env.ps1`, then `adb devices`.
4. Build with `.\scripts\build-debug.ps1` and run `.\scripts\test-phone.ps1`.
5. If Windows does not recognize the device, install the phone manufacturer's
   appropriate USB driver. Do not accept unrelated driver/download offers.

The phone test uses a test-owned temporary SQLite file and never resets the
personal notebook. It does install the same development application ID. Export
a manual backup before testing an existing installation with records.

## Offline shopping journey

- Enable airplane mode. Open Presyo M’lang and choose Start empty.
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
- Force-stop the app using Android app settings, reopen, and verify the exact
  records, bought status and totals. Restore normal airplane-mode preference.
- Edit a price/product/category and confirm past purchase snapshots stay intact.
- Undo a purchase and confirm the linked item becomes Needed and spending drops.

## Portability and accessibility

- Save a JSON backup using the system destination picker. Cancel a separate
  export and confirm all records remain intact.
- Select a backup, cancel the replacement preview, and verify the original records.
- Test a confirmed restore with practice records and compare counts and totals.
- Export CSV, including practice text with a leading formula character; it must
  remain inert text when opened in a spreadsheet.
- Enable Android large text and TalkBack. Add a price and purchase with the
  keyboard open. Save, dates, errors, tab labels and quantity labels must be usable.
- Enter demo mode, confirm the persistent fictional-data banner on every route,
  and return to the real notebook. Demo records must not appear in real spending.
- Check file-picker behavior and local reset with practice data only. Previously
  exported files must remain outside the reset's scope.

## Evidence limits

Record actual results in VERIFICATION.md. Mark storage-full, manufacturer backup
transfer, TalkBack, airplane-mode, physical restart and performance checks NOT RUN
if they were not performed. The inspected debug APK declares INTERNET for
Flutter's development VM service and the AndroidX signature-level
`app.presyomlang.personal.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
No sensitive or broad-storage permissions were found. The application has no
network client or upload SDK; phone offline behavior still needs these checks.
