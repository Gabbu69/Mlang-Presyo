# Connected-phone verification — 17 October 2026

Device: **TECNO KL7**, Android **14**, API **34**, arm64-v8a (also supports
armeabi-v7a). Current Android user: 0. USB debugging is authorized. The device
serial is deliberately omitted. The owner authorized this device run after
previously deferring it.

The personal package is `app.presyomlang.personal`. Automated and fictional
manual practice use `app.presyomlang.personal.integration`, labeled
**Presyo M’lang Tests**, with separate app storage. Inspection found no personal
package installed for user 0 before this run. No other user profile is changed.

## Results

| Check | Result and evidence |
|---|---|
| Authorized device, model/API/ABI, unlocked screen | PASS, observed with Android platform tools. |
| Isolated integration APK identity and installation | PASS on the corrected build. AAPT verified the `.integration` package before installation; install took 9.7 seconds. |
| SQLite shopping/purchase/backup integration journey | PASS on TECNO KL7: actual SQLite close/reopen, purchase state, backup round-trip and Home/Spending rendering. |
| 2,000-record search and category/store filters on phone | First run FAIL after unique search/render (1581.394 ms): clearing the recreated field retained the old filter. Actual lazy-field state-loss bug fixed; full rerun pending. |
| Personal 0.1.1+2 APK install/open | PENDING. |
| Airplane-mode entry and force-stop/reopen | PENDING. |
| Native JSON destination picker, save and cancellation | PENDING. |
| Native restore picker, preview cancellation and replacement | PENDING. |
| 200% Android font scaling and keyboard-visible Save | PENDING. |
| Demo isolation and persistent fictional-data banner | PENDING. |
| TalkBack spoken/touch exploration | NOT RUN until directly observed or confirmed by the owner. |
| Manufacturer cloud backup/device transfer | NOT RUN; another device/transfer path has not been exercised. |
| Storage-full/real provider denial | NOT RUN on hardware; deterministic host/native failure tests pass. |

Temporary device-setting changes used for checks must be restored to their
observed previous values. Only test-owned records and the isolated test package
may be cleared. Personal records must not be reset or uninstalled to make a test
pass. No physical-device result is inferred from host tests.
