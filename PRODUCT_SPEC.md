# Presyo M'lang - Product and engineering specification

**Version:** 0.1.0 personal pilot. **Prepared:** 16 October 2026.
**Scope:** Android application; offline first; personal use initially, community contributions later.
**Status:** offline Android V1 implemented; internal debug APK built and inspected; all 69 host tests, formatting and analysis pass. Physical-phone installation and acceptance remain NOT RUN by owner choice. See `docs/VERIFICATION.md` for the actual evidence and limitations. The requirements below remain the behavior contract; community features remain future scope.

## 1. Product promise

Help a shopper answer: What should I buy? What did I pay before? What prices have I recorded elsewhere? How much have I actually spent?

Working tagline: **Your local price notebook and shopping companion.**

The owner is building this for personal use and residents of M'lang, North Cotabato. The design should work for any resident's own records, without claiming comprehensive coverage of the municipality. No real store list, current price feed, Kadiwa schedule, or official partnership is supplied.

### Success for the first version

A person can create a shopping list, record comparable prices, record actual purchases, inspect the correct budget, close the app, and recover the same information offline. They can export a backup and restore it without data loss.

The first release is useful even with one user. The app must not depend on a crowd of contributors before delivering value.

## 2. Release boundaries

| Personal pilot: build now | Community edition: later | Explicitly excluded initially |
|---|---|---|
| Local product and store notebook | Optional contributor accounts | Checkout, payments, delivery |
| Dated price observations | Moderated public price submissions | Seller commissions or advertisements |
| Like-for-like unit comparisons | Seller-posted records and corrections | AI price forecasts or chatbot |
| Shopping lists and list budgets | Downloaded community records | Receipt OCR and barcode catalog |
| Actual grocery spending | Server-side authorization and moderation | GPS, maps, travel optimization |
| Price history as a dated list | Abuse reporting and takedowns | Inventory or availability guarantees |
| JSON backup/restore and CSV exports | Translation after local review | Scraping Facebook or shop websites |

No login, server, paid API key, or network connection is required for the app's Version 1 core workflow. Development tools and future distribution are separate considerations. The app is not a store marketplace, price regulator, investment tool, or official LGU service.

## 3. Users and essential journeys

**Primary user: household shopper or student.** They plan a trip, enter prices they personally see, and keep their own grocery spending private.

**Secondary user: another resident using their own installation.** Until Version 2, their database is separate. There is no automatic community sharing.

**Later roles:** optional contributor, seller, moderator, and public reader. Do not implement these now.

### Before shopping

Create 'Weekend groceries', optionally enter a budget, add products and quantities, and choose an estimate from an eligible saved price or enter a manual line estimate. Display all items that still have no estimate.

### At the store

Open Add Price. Select or create a product and store inline. Enter amount, amount-of-product, loose or packaged sale, and observation date. Save with a clear success state and duplicate-tap protection.

### After buying

Tap an item to mark it bought. First show a confirmation sheet for actual quantity, total amount paid, purchase date, and optional store. Only Save records a purchase and changes the item status. Cancel changes nothing.

A saved purchase may offer a separate Add Price form, but the shopper must confirm the actual retail price basis. Do not infer that a discounted receipt total is an unconditional per-package offer.

### Later

Look at spending for a selected month, previous observations for a product, or a saved shopping list. Export a backup through the device's system file/share interface.

## 4. Navigation and screens

Use four bottom tabs: **Home | Lists | Prices | Spending**. Open Settings from an app-bar button. No Community tab, disabled fake tabs, social feed, or splash animation that delays entry.

### Home

Show the most recent active list, its actual spending, its projected total or incomplete subtotal, and the number of items still needed. Offer Create List and Add Price. Show a small recent-records section, each with a date. With no data, use helpful empty-state actions instead of fake statistics.

Do not display a 'money saved' figure because no defensible baseline is established. Do not call locally saved records live market data.

### Lists

Show active and archived lists. A detail screen includes the list budget, items grouped as Needed/Bought/Skipped, quantity, estimate, and actual paid value where present. Add products inline; duplicate a previous list into a new list with all statuses reset and estimates explicitly rechecked or cleared.

A price copied into a list is a snapshot. New observations do not silently change an existing plan. Offer an explicit Refresh Estimate action. When a manual-total estimate's quantity is edited, clear it or require confirmation; do not guess a proportional price.

Marking bought opens actual-purchase confirmation. Undoing a purchase warns that its spending entry will be removed and performs both changes atomically. Archive lists rather than deleting associated spending. Version 1 supports one purchase per list item; split separate buys into separate items.

### Prices

Default to My Price Records. Search products, filter category or store, and inspect history. The Add Price form has product, store, total price for the stated quantity, quantity and unit, loose/packaged flag, observation date, source, regular/promotional flag, and optional short notes.

Require brand/variant/grade when those distinctions matter. Price source options: Personally observed, My purchase, Seller quote. None imply independent verification. Do not request a photo, GPS permission, or contact list.

Product Detail shows comparable offers with both original quantity/price and normalized unit price, source, observed date, and age label. A 'Use for list' action chooses a specific offer, not a supposed universal cheapest store.

Price history can be a dated table/list. A chart is not needed for the first release. Keep records for different package sizes legible rather than connecting unlike package prices into a misleading trend.

### Spending

Show actual grocery spending for the chosen calendar month, optional monthly budget, category totals, and editable purchase entries. This is based only on the purchase ledger, not checked boxes, price observations, or list estimates.

Support a standalone Add Purchase action for something not planned in a list. Changing a linked purchase updates the related list view without creating another expense.

### Settings and onboarding

Show a short first-run explanation: 'Your own shopping lists and price records. Recorded prices may change.' Provide Start Empty and optional Try Demo. No registration wall or unnecessary personal profile.

Settings includes manage products/stores, monthly budget, backup/restore, CSV exports, privacy explanation, demo toggle, delete local data, app version, and an independent-project disclaimer. The confirmed local reset excludes any exports already saved or shared; explain that clearly.

## 5. Visual direction and accessibility

Proposed palette: deep green primary, warm cream background, orange accent, charcoal text, and white cards. These are design choices, not a requirement to use orange for small text. Validate actual contrast before accepting the UI.

Use a simple shopping-bag/price-tag concept for an eventual icon, not a government seal. Use system or bundled fonts, roughly 16 logical pixels for body text, large prices, and minimal decoration. Prefer a simple light theme for the pilot; a second theme is not required.

Implementation targets: at least 48 by 48 logical-pixel touch targets; 4.5:1 contrast for ordinary text; usable layouts at 200% text scale; meaningful screen-reader labels; no status conveyed only by color; visible focus and keyboard behavior. Test on a narrow phone layout. These are targets to verify, not performance or accessibility results already achieved.

Keep interface language simple English. Externalize strings for later reviewed translations. Permit users' own local-language product/store names and Unicode punctuation. Do not assume every resident prefers the same local language.

## 6. Price and quantity rules

### 6.1 Money

Store all money as integer centavos: PHP 45.50 is 4550. Parse decimal text exactly; do not parse money through binary floating-point. Show Philippine peso formatting with two decimals.

Quotes must be positive. Actual purchases and explicitly entered budgets/estimates may be zero. An absent budget or estimate is null and is different from zero. Reject negative, non-finite, exponent, malformed, or oversized inputs with a useful message.

Initial validation caps: a single quote, purchase total, or manual estimate at 100,000,000 centavos; budgets at 1,000,000,000 centavos; canonical quantity at 1,000,000 base units. Keep aggregate arithmetic checked. These are implementation guardrails and may be revised with corresponding tests.

### 6.2 Quantity and product identity

Each product has one quantity kind: mass, volume, or count. Canonical quantities are integer grams, milliliters, or pieces. Accept up to three decimal places for kg or L only when exactly representable in those base units. Require whole g, mL, and pieces in Version 1.

A pack or tray is not a universal unit. Record its contained amount, such as 500 g or 30 pieces, and mark it packaged. Do not compare a tray with no contained count to individual eggs. Reject cups, bundles, or other unspecified conversions for automatic comparison; the user must supply a measured canonical quantity.

Group comparisons by the same user-defined product variant: brand where relevant, variety/flavor, grade or size where relevant, and quantity kind. Different package sizes may be compared for unit value. Do not merge different brands, egg sizes, vegetable grades, or unknown variants automatically. Grouping quality depends on accurate user entry.

Do not allow changing a product's quantity kind once records reference it. Create a new product instead. Warn on apparent duplicate products but do not merge data without user confirmation.

### 6.3 Comparison calculations

Display mass prices per kilogram, volume prices per liter, and count prices per piece. For mass:

`unit_price_centavos_per_kg = quoted_centavos * 1000 / offered_grams`

Keep this as a rational value for ordering. Compare records A and B using cross-multiplication of price and quantity; only round the displayed amount. Do not rank on rounded display values. Use half-up rounding for positive money at the final display or line-total boundary.

Fictional example for tests only:

| Record | Original price | Normalized value |
|---|---|---|
| Demo Stall A | PHP 45 for 500 g | PHP 90.00/kg |
| Demo Stall B | PHP 85 for 1 kg | PHP 85.00/kg |

The second record has a lower unit price. It is not automatically cheaper for a shopper who needs only one 500 g sealed pack. Show both original package price and normalized value.

For a loose product estimate, multiply requested quantity by the exact quoted fraction and round the final line total once. For a packaged product estimate, buy whole packages:

`required_packages = ceiling(requested_base_quantity / offered_base_quantity)`

`estimated_total_centavos = required_packages * quoted_centavos`

For 750 g wanted, a 500 g sealed pack at PHP 45 requires two packs, costing PHP 90. A loose 500 g quote at PHP 45 yields PHP 67.50 for 750 g. Show any extra quantity due to whole packages.

Do not include transport costs or claim basket optimization in Version 1. Promotions or conditional prices can be saved and labeled but are excluded from default best-unit-price ranking. Do not model membership prices or 'buy two get one' automatically.

### 6.4 Date, recency, and latest-record policy

Store observation dates as calendar dates in Asia/Manila. Technical created/updated timestamps are UTC. Do not derive recency from the last edit time. Reject future observation dates.

Project-default labels: Today for age 0; Recent record for 1-7 days; Older record for 8-30 days; Old record for 31+ days. Always show the actual date as well. Seven days is a user-interface default, not a guarantee the price remains valid.

Before ranking, choose the latest non-deleted observation for each group of product, store, offered base quantity, selling mode, and offer type. For records on the same observed date, use updated timestamp and stable ID as deterministic tie-breakers. Older observations stay in history but must not defeat a newer higher price for the same offer.

By default compare only regular records observed within the last seven days inclusive. When none exist, say 'No recent comparable records' and offer Show Older Records. An old record never receives a current/recent label because the user enabled that filter.

Allowed summary: 'Lowest recorded unit price among these records.' Never 'cheapest in M'lang', 'guaranteed lowest price', or 'available now'. Remind users to confirm price and availability with the seller.

## 7. Shopping budgets and actual spending

Use these definitions consistently:

- `actual_spent`: sum of actual purchase entries linked to the list.
- `remaining_estimate`: sum of known estimates for Needed items only; ignore Skipped and Bought estimates.
- `projected_total`: actual_spent plus remaining_estimate.
- `budget_left_after_purchases`: list budget minus actual_spent, when a budget exists.
- `projected_balance`: list budget minus projected_total, only presented as complete when every Needed item has an estimate.

When one or more Needed items have no estimate, label the sum 'Known projected subtotal' and show the missing count. Do not show a green 'within budget' assurance based on incomplete data. A zero budget must not trigger division by zero.

Monthly actual spending uses `purchased_on` within the selected Asia/Manila calendar month, regardless of when the list was created. Do not double-count a purchase because it appears both on a list and in Spending.

One list item maps to at most one active purchase ledger entry in Version 1, enforced with a unique constraint. The bought-state transition and purchase insertion/update occur in one transaction. Block repeated submit actions and keep the database constraint as the final guard.

## 8. Proposed local data model

Use stable UUID identifiers. Keep the schema lean; table names may change with a recorded reason. Enable foreign keys and validate constraints in both domain code and the database where practical.

| Table | Core fields |
|---|---|
| products | id, name, brand, variant_grade, category, quantity_kind, archived, created_at_utc, updated_at_utc |
| stores | id, name, optional barangay_text, optional landmark, archived, created_at_utc, updated_at_utc |
| price_records | id, product_id, store_id, quoted_centavos, offered_quantity_base, selling_mode, offer_type, source_type, observed_on, notes, created_at_utc, updated_at_utc |
| shopping_lists | id, title, budget_centavos nullable, status, created_at_utc, updated_at_utc |
| list_items | id, list_id, product_id, requested_quantity_base, estimate_mode, estimate_total_centavos nullable, source_price_id nullable, estimate_basis_snapshot nullable, status, display_order |
| purchases | id, list_item_id nullable and unique, product_id, store_id nullable, actual_quantity_base, actual_total_centavos, purchased_on, product_snapshot, store_snapshot, created_at_utc, updated_at_utc |
| app_settings | versioned settings including onboarding and selected defaults; no sensitive profile |
| monthly_budgets | month YYYY-MM, budget_centavos; one record per month |

Snapshot product name/category/quantity kind and any relevant price basis so later catalog edits do not rewrite historical meanings. Spending categories use purchase snapshots, not a live product category that might change retroactively.

Price history remains until the user edits/deletes a record. Deleting a source price must not remove purchases or alter frozen estimates: detach nullable references while preserving snapshots. Archive referenced products/stores and lists instead of cascading deletes. Local data reset is a separate confirmed action.

Index product/store/date for price lookup, list_id for items, and purchased_on for spending. Do not add cloud ownership columns, sync jobs, or a server SDK before the community milestone is separately authorized.

## 9. Architecture and dependencies

Recommended default: Flutter/Dart; Drift over local SQLite; Riverpod for state; Material widgets; simple Navigator routes unless a routing package solves an actual need. Separate UI, controllers, pure domain functions, and repositories. This follows the general separation described in Flutter architecture documentation [S1, S2].

Drift supplies a structured local database path with migration tooling; use its current documented setup and migration testing rather than assuming migrations are automatic [S3, S4]. Riverpod is the chosen state-management approach, not a requirement imposed by Flutter [S5].

Select compatible package versions at implementation time and record them. Supporting dependencies may include formatting, UUID generation, timezone conversion, and system file/share access. Avoid receipt processing, chart libraries, map SDKs, and network clients until actually needed.

Suggested organization:

```text
lib/
  app/                 # app shell, routes, theme, localizable strings
  core/                # exact money/quantity/date helpers, errors
  data/                # database, migrations, repositories, backup
  features/
    home/
    lists/
    prices/
    spending/
    settings/
test/
  domain/
  repositories/
  migrations/
  widgets/
integration_test/
docs/
```

Feature folders may contain small domain/controller/presentation files; avoid a giant main.dart. Prefer repository interfaces that can be tested with in-memory databases. Do not use global mutable demo arrays as real storage.

## 10. Backup, restore, privacy, and failure behavior

### Backup and export

Provide a user-triggered, versioned logical JSON backup of real records and settings, taken from a consistent database read. Include `format_version`, `exported_at_utc`, currency, timezone, and all required referenced rows. The backup format version is separate from the internal database schema version.

Provide separate readable CSV exports of prices and purchases. CSV is not the restoration format. Escape text cells beginning with spreadsheet formula characters, including after whitespace, and quote fields correctly. Preserve numeric amounts as numbers in the documented currency units.

Warn before export: 'This file contains your private records and is not encrypted. Share it only with people you trust.' Let the user choose the destination through an appropriate system picker/share interface. Do not require broad storage access or upload files automatically. Clean temporary app-owned export files after use where practical.

Restore is replace-only in Version 1. Validate file size (initial cap 10 MB), supported format version, field types, dates, IDs, enum values, limits, row count (initial cap 20,000), and references before changing anything. Show a counts summary, warn about replacement, and offer backup first. After explicit confirmation, replace in one database transaction. Parse errors, canceled dialogs, and interrupted/failed writes must leave existing data intact. Reject future format versions without partial import.

### Privacy and local storage

Collect no names, email addresses, phone numbers, GPS coordinates, or user identifiers in Version 1. Store only user-entered shopping data in the app's private storage. Include no analytics, ads, crash-report uploads, or runtime font fetching.

Android may back up application data unless backup behavior is configured. Review both legacy backup rules and newer data-extraction rules, including device transfers, before making a device-only privacy claim [S7]. Version 1 should exclude the app's shopping databases and preferences from automatic cloud backup, with explicit manual exports as the supported backup mechanism. Verify behavior on the supported Android targets and disclose any unverified device-transfer limitation. Do not promise encryption merely because the app uses SQLite.

Removing the app may remove local records; warn users to export a backup. Deleting local data cannot retract an export already sent elsewhere. Do not log shopping contents, amounts, or private notes in release builds.

Before a shared community release, assess applicable Philippine privacy duties and provide an accurate notice and consent/rights flows. Transparency, legitimate purpose, and proportionality are principles in the Data Privacy Act, not a guarantee that this plan alone makes the finished app compliant [S9].

### Errors

Keep unsaved form data after a recoverable save failure. Show understandable validation, retry, and cancellation states. On storage-full errors, fail safely without pretending a save succeeded. Never solve a migration problem by deleting the user's database. Distinguish empty data from load failure.

## 11. Community edition - separately authorized Version 2

Only proceed after the personal pilot is reliable and an actual maintainer agrees to moderation and operating costs.

The private database and public price catalog must remain distinct. Sharing a price creates an explicitly approved public submission containing only product, store/business location, amount, quantity, observed date, and a public source label. It must not upload lists, budgets, purchase history, private notes, backups, or precise home locations.

Readers may browse a public catalog without an account if the chosen backend permits safe rate-limited access. Require accounts for contributions. Proposed roles: contributor, seller, moderator. Server authorization must enforce ownership and moderation; hiding a button is not access control.

Submission states: draft locally, queued, pending review, approved, rejected, corrected/withdrawn. Separate public record review status from source identity. 'Seller-posted' is not proof of the lowest price, and 'reviewed' must state whether review checked completeness or actually verified a price. Publish observation date and last sync time prominently.

Use offline read caching and an explicit refresh first, not complex always-on synchronization. Retry queued submissions with a stable idempotency key to prevent duplicates. Keep public correction history and server timestamps; reject unauthorized updates. Do not let local clock edits forge approval or recency.

Add reporting, rate limits, moderator audit logs, a correction/takedown procedure, and tested account deletion behavior before open submissions. Verify participating business details and obtain appropriate permission for nonpublic contact information. Keep admin credentials and privileged API keys off the Android client.

Choose a hosted database/API only after comparing current support, cost, security, data location, and maintenance needs. No particular service's free tier or availability is assumed by this plan. No retailer or LGU partnership may be invented.

## 12. Pilot and release readiness

A suggested initial pilot is the owner plus four other willing household shoppers; expand to a few willing sellers only when investigating the community edition. This is a proposed recruitment target, not a claim of demand.

Observe whether users can add a familiar price, make a list, record a purchase, and distinguish package price from unit price without coaching. Ask which step is confusing, whether recording prices feels worthwhile, and which information becomes outdated fastest. Do not collect their private records merely to evaluate usability.

Proposed technical targets: the core workflow works in airplane mode; searching 2,000 local price records remains responsive; repeated save actions never duplicate purchases; backups round-trip; no data loss on a tested migration; ordinary actions remain accessible with large text. Measure results on a named device instead of declaring targets achieved.

Use development APKs for internal testing. Configure owner-controlled release signing and a stable application ID before wider distribution. Inspect actual build outputs; Android APK and app-bundle workflows are documented by Flutter [S6]. Recheck current store policies at publication time. Do not publish or spend money automatically.

Version 1 is done only when the relevant acceptance tests pass, unrun checks are disclosed, and a real Android build is tested. Community readiness is a separate decision, not a label added to the same prototype.
