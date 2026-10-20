# Acceptance tests - PresyoGo

These are required test specifications, not tests already run. All prices and stores below are fictional fixtures. Use deterministic clocks and in-memory/test databases; never use real user shopping data as test fixtures.

## Money and quantities

**T01 Exact money.** Parsing PHP 45.50 yields 4550 centavos. Formatting returns two decimals. Ten values of 10 centavos sum to exactly 100 centavos. No binary floating-point conversion is used for money.

**T02 Invalid input.** Reject negative quotes, zero quote quantity, negative budgets, malformed numbers, exponent inputs, non-finite values, and configured range overflows. Allow zero as an explicitly entered budget or actual purchase. Keep a missing estimate null.

**T03 Canonical units.** 0.5 kg becomes 500 g; 1.25 L becomes 1250 mL; 12 pieces remains 12. Reject fractional pieces and unsupported units. Do not convert kilograms to liters.

**T04 Rounding once.** A loose quote of 100 centavos for 3 g yields an estimate of exactly 100 centavos for 3 g, not 99 from prematurely rounded per-gram values. Half of one centavo rounds to one centavo at the final positive-money boundary.

## Comparisons and dates

**T05 Unit comparison.** Demo A: PHP 45/500 g; Demo B: PHP 85/1000 g for the same variant. Display PHP 90.00/kg and PHP 85.00/kg respectively. B ranks lower on unit price; do not claim guaranteed current availability or municipality-wide coverage.

**T06 Whole packs.** At PHP 45/500 g packaged, requested 750 g requires 2 packages, total PHP 90, and 250 g extra. The same loose quote yields PHP 67.50. Requesting 500 g should show that a PHP 85/1 kg sealed package costs PHP 85, despite its better unit value.

**T07 Like for like.** Different brands, variants/grades, egg sizes, or quantity kinds do not enter the same automatic ranking. A tray with unspecified count is not comparable to individual eggs.

**T08 Latest record wins.** Same product/store/quantity/selling mode/offer type: a record from yesterday at PHP 90 replaces a three-day-old record at PHP 80 in the comparison candidate set. Both remain in history. Use deterministic same-day tie-breaking.

**T09 Freshness boundary.** With Manila date 2026-10-16, a 2026-10-09 observation has age 7 and is included by default. 2026-10-08 has age 8 and is excluded until older records are enabled. Enabling older records does not change their age labels.

**T10 No recent records.** Display a helpful empty state and Show Older Records. Do not show a stale lowest-price card labeled Today. Reject an observation dated after the injected Manila today.

**T11 Timezone.** Inject UTC 2026-10-16T15:30:00Z: Manila date is 2026-10-16. At UTC 2026-10-16T16:30:00Z it is 2026-10-17. A different device timezone must not change these outcomes. Editing a record does not refresh its observation age.

**T12 Promotion and precision.** Promotional records are excluded by default and labeled in history. Two distinct unit-price fractions that round to the same displayed amount remain correctly ordered using their exact values.

## Lists and spending

**T13 Complete projection.** Budget PHP 500; actual spent PHP 165; remaining known estimates PHP 310. Projected total is PHP 475; budget remaining after purchases is PHP 335; projected balance is PHP 25. Do not mix up these three amounts.

**T14 Incomplete projection.** Add one needed item with a null estimate. Label PHP 475 as a known projected subtotal and show one unpriced item. Do not claim the list is within budget. A skipped item does not contribute to the remaining estimate.

**T15 Bought is explicit.** Tapping bought opens actual-purchase confirmation. Cancel changes neither item nor ledger. Saving creates one purchase and changes status in one transaction. A double tap, repeated callback, or retry does not create a second purchase.

**T16 Undo and failure.** Undo removes the linked purchase and restores needed status atomically after confirmation. Simulated database failure rolls back both changes. A zero budget does not cause divide-by-zero or hide overspending.

**T17 Historical integrity.** Edit or delete the price used for an estimate; existing actual spending does not change. Catalog renames/category changes do not rewrite purchase snapshots. Deleting a source quote preserves frozen list estimates.

**T18 Monthly boundaries.** A purchase on 2026-09-30 appears in September; 2026-10-01 appears in October, even when both are linked to the same list. Use the stored Manila purchase date, not list creation or UTC creation date.

**T19 Manual estimate editing.** Changing the requested quantity for a manual-total estimate clears it or explicitly requires reconfirmation. Changing it for a selected-price estimate recalculates against the frozen basis. No silent refresh from a newer quote.

**T20 Duplicate/archive.** Duplicating a completed list creates new item IDs, needed states, and no purchases. Estimates are cleared or explicitly revalidated. Archiving the original list does not remove its expenses.

## Persistence and portability

**T21 Offline restart.** In airplane mode, create a product, store, observation, list, and purchase. Force-stop and reopen. All records and calculated summaries remain correct. No sign-in, font download, or backend is needed.

**T22 Referential integrity.** Invalid product/store references are rejected. Referenced catalog entries archive instead of destructive cascade deletion. A product quantity-kind change is prohibited once referenced.

**T23 Migration.** Apply a representative schema upgrade to a populated older test database. IDs, quotes, purchases, snapshots, and totals remain correct. Migration failure does not delete the database. Test foreign keys as well as row counts.

**T24 Backup round-trip.** Export a consistent real-data JSON backup, restore into an empty test installation, and compare logical records, IDs, quantities, dates, budgets, snapshots, and totals. CSV alone is not a supported restore source.

**T25 Restore validation.** Invalid JSON, unsupported format version, duplicate IDs, invalid enum, out-of-range quantity, broken reference, oversized file, and excessive row count are rejected before mutation. Canceling the preview leaves all data intact.

**T26 Restore transaction.** Inject a failure halfway through a replacement restore. Existing records remain exactly as before. Show an error, not 'restored successfully'. Warn about replacing records and offer export first.

**T27 CSV safety.** Product/store/notes cells beginning with =, +, -, @, tab, or carriage return (including after leading whitespace) are escaped as inert text. Commas, quotes, newlines, Unicode, and the peso symbol export correctly. Numeric money columns remain correctly documented.

**T28 Export boundaries.** Cancellation does not erase records. Temporary exports are cleaned where practical. Privacy copy warns that files are unencrypted and that the user-selected external recipient/destination may retain them.

## Privacy, accessibility, and delivery

**T29 Demo isolation.** Fresh real mode has no fictional prices or spending. Every demo screen shows a persistent sample-data label. Switching databases does not mix records. Demo records are excluded from real backups and spending.

**T30 Permission/network review.** Inspect the compiled manifest and dependency behavior. Only optional foreground coarse/fine location is allowed after an explicit button tap. No startup/background location, contacts, camera, microphone, broad storage, analytics, ads, or app-initiated network calls. Document Flutter's debug-only Internet permission separately.

**T31 Backup policy.** Review the Android cloud-backup and data-extraction configuration for supported API levels. Test where possible. Do not equate allowBackup=false alone with verified prevention of every manufacturer-specific device transfer.

**T32 Local reset.** After explicit confirmation, all real in-app data is removed. Cancel is safe. Explain that previously exported copies cannot be retracted. Do not accidentally remove a user-chosen external file.

**T33 Accessible flow.** With large text and screen-reader use, complete adding a price and recording a purchase. Inputs, buttons, tab labels, dates, and errors are understandable; the keyboard does not hide Save. Check narrow layouts and contrast.

**T34 Error recovery.** A storage-full or database-write failure does not show success, double-count a purchase, or discard form input unnecessarily. Distinguish a failed load from an empty notebook.

**T35 Actual build evidence.** Record actual formatting, analysis, unit/widget/integration test results and any NOT RUN checks. Verify the produced APK path and install/open it on a named Android device when available. A UI screenshot alone is insufficient.

**T36 Signing and scope.** A development APK is labeled as such. Public release requires owner-controlled release signing, not debug signing hidden in a release configuration. No backend, public posting, paid service, or publication is created by these milestones.

## Location and PresyoGo update — 0.2.0+3

**T37 Shopping area.** All areas is the initial default. Manual area labels match
after case/whitespace normalization. Phone location is captured only on a button
tap. Preview radius (5/10/25 km; default 10), coordinates, accuracy and capture
time before Save. Cancel leaves the prior saved choice unchanged. A saved center
does not move automatically; Refresh location requires another explicit tap.

**T38 Location recovery.** Test approximate/precise grants, denial, disabled
providers, a 20-second acquisition timeout, stale/invalid fixes and lifecycle
cancellation. Offer Retry, manual selection and All areas without losing the
prior saved scope. Repeated taps must not create competing requests or writes.

**T39 Explicit store tags.** Store area/GPS tags are optional and persist only
after saving the store form. Tagging and removing a tag are explicit actions.
Cancel changes nothing. Shopping area changes never tag or move existing stores.

**T40 Consistent scope.** Apply area scope to Home recent records, price browsing,
product comparisons/history and list-estimate offer selection. Test inside, on
and outside radius boundaries, unlocated stores and normalized manual labels.
Explain excluded stores and offer a screen-local Show all areas override. With
no matching prices, offer Add store, Add price and Show all areas. Lists, spending,
historical purchases and frozen estimates remain accessible and unchanged.

**T41 Location compatibility.** Upgrade a genuinely populated schema 1 database
to schema 2 and compare every original record, snapshot and total; validate
foreign keys and reopen. Import actual format 1 and round-trip format 2 backups.
Reject malformed or partial location tags before mutation. Test restore rollback
and formula-safe CSV location text. Export warnings disclose unencrypted tags.

**T42 Rename and delivery.** The title/launcher/About/dialogs say PresyoGo and the
isolated app says PresyoGo Tests. Keep package IDs, channels, signing identity,
database paths and old backup compatibility. Inspect the 0.2.0+3 debug APK and
record its hash. Test 200% text, keyboard visibility and screen-reader feedback.
Never uninstall the personal notebook to resolve an update failure.

## Suggested pilot observations

Ask a willing tester to create a list, enter two comparable fictional practice prices, and record a purchase without instructions. Observe where they hesitate. Then test with their own records without collecting those records yourself. Confirm they understand an observed price is not a live guarantee and a better unit price may require buying a larger package.

## Proposed performance checks

On an identified pilot phone, test startup, list scrolling, search/filter with 2,000 local price records, and repeated exports. Record measured results and memory behavior; do not report invented measurements or turn an arbitrary target into a performance claim.
