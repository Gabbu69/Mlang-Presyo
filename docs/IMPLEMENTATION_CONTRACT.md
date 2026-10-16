# Internal implementation contract

Version 0.1.0, Android application ID `app.presyomlang.personal`.
This supplements the supplied specification and the user's full-V1 plan.

## Shared data types (`lib/core/models.dart`)

Use `typedef Row = Map<String, dynamic>` for validated serializable entity records.
JSON keys and table columns use the exact snake_case fields in PRODUCT_SPEC section 8.
This keeps backups, repository validation and UI form drafts on one representation;
all writes go through validating repository methods. Never pass unvalidated rows to SQL.

`AppData` has final `List<Row>` fields `products`, `stores`, `prices`, `lists`,
`items`, `purchases`; `Map<String,dynamic> settings`; `Map<String,int> monthlyBudgets`.
It supplies `AppData.empty()`, `Row product(String id)`, `Row? store(String? id)`,
`List<Row> listItems(String listId)` and `Row? purchaseFor(String itemId)`.
Missing required entities throw `ValidationException`, not a fake record.
`ValidationException` carries a readable `message` and overrides toString.

Enums are serialized strings: quantity_kind `mass|volume|count`, selling_mode
`loose|packaged`, offer_type `regular|promotional|conditional`, source_type
`observed|purchase|seller_quote`, list status `active|archived`, item status
`needed|bought|skipped`, estimate_mode `none|manual|price`.
Strings UTC timestamps are ISO8601 with Z; business dates YYYY-MM-DD.
Catalog archive fields are Dart booleans in domain/JSON, 0/1 in SQLite.
Defaults for product brand/variant_grade are empty strings and category Uncategorized.

## Pure helpers (`lib/core/domain.dart`)

`int parseMoney(String input, {bool positive=false, int max=100000000})`
`String money(int centavos)` (peso sign, grouping, two decimals; supports negatives)
`String moneyInput(int centavos)` (ungrouped decimal, for forms)
`int parseQuantity(String input, String unit, String kind)`
`String baseUnit(String kind)` and `String quantityLabel(int quantity,String kind)`
`int roundHalfUp(int numerator,int denominator)` (exact BigInt intermediates)
`DateTime manilaToday([DateTime? instant])` (UTC-based calendar date)
`String dateText(DateTime date)`; `void validateDate(String value,{DateTime? now})`
`int ageDays(String observedOn,{DateTime? now})`; `String ageLabel(String observedOn,{DateTime? now})`
`List<Row> comparablePrices(Iterable<Row> prices,String productId,{bool older=false,DateTime? now})`
`int normalizedCentavos(Row price,String kind)` (rounded display only)
`Estimate estimatePrice(Row basis,int requestedQuantity)` with fields totalCentavos,
packages (nullable for loose), extraQuantity.
`Row priceSnapshot(Row price,Row product,Row store)` supplies format_version=1,
quoted_centavos,offered_quantity_base,selling_mode,observed_on,product_name,store_name.
`ListTotals listTotals(AppData data,String listId)` with actualSpent,
remainingEstimate,projectedTotal,missingEstimates,budgetLeft,projectedBalance.
`int monthlySpent(AppData data,String month)`; `Map<String,int> categoryTotals(AppData data,String month)`.

## Persistence (`lib/data/repository.dart`, `lib/data/database.dart`)

`AppDatabase` uses Drift native SQLite, has `AppDatabase.memory()` for tests and
`AppDatabase.file(File file)` for Android. Generated Drift schema preferred.
`AppRepository(AppDatabase db,{bool demo=false,DateTime Function()? clock})`.
Public `bool get isDemo`, `Future<void> close()`, `Future<AppData> load()`.
`Future<void> saveProduct(Row)`, `saveStore(Row)`, `savePrice(Row)`, `saveList(Row)`,
`saveItem(Row)`, `savePurchase(Row)`; `Future<void> deletePrice(String id)`,
`deleteItem(String id)` (reject bought), `deletePurchase(String id)` (undo linked atomically),
`duplicateList(String listId)` (new IDs, cleared estimates; returns Future<String>),
`setSetting(String key,dynamic value)`, `setMonthlyBudget(String month,int? centavos)`,
`reset()` (only this database), `seedDemo()` (demo only).
UUID/timestamp defaults added to new rows by repository if absent. Existing IDs
must preserve created timestamps; saves update updated_at_utc from injected clock.
savePurchase atomically maintains linked item bought state. Repeated linked save
resolves by list_item_id and updates the existing row instead of duplicating it.
saveItem disallows changing product/status of bought item except via purchase APIs.
Quantity edits clear manual estimates or recalculate selected-price snapshots.

## Portability (`lib/data/portability.dart`)

`String encodeBackup(AppData data,{DateTime? now})`;
`AppData decodeBackup(String text,{DateTime? now})` validates all rows/references/invariants,
10MiB UTF8 cap and 20000 aggregate rows, no mutation.
`String pricesCsv(AppData data)`, `String purchasesCsv(AppData data)`.
`AppRepository.restore(AppData data,{void Function()? beforeCommit})` revalidates and
atomically replaces real data; optional callback allows rollback fault tests.
Backup/export and restore are UI-disabled in demo; repository restore rejects demo.
Backup shape: format_version=1,exported_at_utc,currency=PHP,timezone=Asia/Manila,
products,stores,price_records,shopping_lists,list_items,purchases,app_settings,
monthly_budgets (array of {month,budget_centavos}).

## Owner actions and defaults

New SDK licenses require owner review. Phone USB debugging/authorization is manual.
Duplicating clears estimates. Actual quantities positive; actual money may be zero.
Reject future purchases. Monthly budgets never carry automatically.
Demo files are physically isolated and every demo route is labeled.
No release signing, publication or GitHub push in this implementation.
