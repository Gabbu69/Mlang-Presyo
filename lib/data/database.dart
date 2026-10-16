import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Drift owns connections, transactions, and schema versioning. Explicit SQL
/// keeps constraints visible beside the versioned schema, without generated
/// companions for the validated logical records used by this application.
class AppDatabase extends GeneratedDatabase {
  AppDatabase.memory() : super(NativeDatabase.memory());
  AppDatabase.file(File file) : super(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final statement in schemaStatements) {
        await customStatement(statement);
      }
    },
    onUpgrade: (_, from, to) async => throw StateError(
      'No reviewed migration from schema $from to $to. Records were preserved.',
    ),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final result = await customSelect('PRAGMA foreign_keys').getSingle();
      if (result.data.values.single != 1) {
        throw StateError('Foreign-key enforcement is unavailable.');
      }
      final violations = await customSelect('PRAGMA foreign_key_check').get();
      if (violations.isNotEmpty) {
        throw StateError('The database contains invalid references.');
      }
    },
  );

  Future<List<Map<String, Object?>>> exportedSchema() async =>
      (await customSelect(
        "SELECT type, name, tbl_name, sql FROM sqlite_master "
        "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
      ).get()).map((row) => row.data).toList();
}

const schemaStatements = <String>[
  '''CREATE TABLE products (
    id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 200),
    brand TEXT NOT NULL, variant_grade TEXT NOT NULL, category TEXT NOT NULL,
    quantity_kind TEXT NOT NULL CHECK(quantity_kind IN ('mass','volume','count')),
    archived INTEGER NOT NULL CHECK(archived IN (0,1)),
    created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL
  )''',
  '''CREATE TABLE stores (
    id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 200),
    barangay_text TEXT, landmark TEXT, archived INTEGER NOT NULL CHECK(archived IN (0,1)),
    created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL
  )''',
  '''CREATE TABLE price_records (
    id TEXT PRIMARY KEY NOT NULL,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    store_id TEXT NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
    quoted_centavos INTEGER NOT NULL CHECK(typeof(quoted_centavos)='integer' AND quoted_centavos BETWEEN 1 AND 100000000),
    offered_quantity_base INTEGER NOT NULL CHECK(typeof(offered_quantity_base)='integer' AND offered_quantity_base BETWEEN 1 AND 1000000),
    selling_mode TEXT NOT NULL CHECK(selling_mode IN ('loose','packaged')),
    offer_type TEXT NOT NULL CHECK(offer_type IN ('regular','promotional','conditional')),
    source_type TEXT NOT NULL CHECK(source_type IN ('observed','purchase','seller_quote')),
    observed_on TEXT NOT NULL, notes TEXT NOT NULL,
    created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL
  )''',
  '''CREATE TABLE shopping_lists (
    id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 200),
    budget_centavos INTEGER CHECK(budget_centavos IS NULL OR (typeof(budget_centavos)='integer' AND budget_centavos BETWEEN 0 AND 1000000000)),
    status TEXT NOT NULL CHECK(status IN ('active','archived')),
    created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL
  )''',
  '''CREATE TABLE list_items (
    id TEXT PRIMARY KEY NOT NULL,
    list_id TEXT NOT NULL REFERENCES shopping_lists(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    requested_quantity_base INTEGER NOT NULL CHECK(typeof(requested_quantity_base)='integer' AND requested_quantity_base BETWEEN 1 AND 1000000),
    estimate_mode TEXT NOT NULL CHECK(estimate_mode IN ('none','manual','price')),
    estimate_total_centavos INTEGER CHECK(estimate_total_centavos IS NULL OR (typeof(estimate_total_centavos)='integer' AND estimate_total_centavos BETWEEN 0 AND 100000000000000)),
    source_price_id TEXT REFERENCES price_records(id) ON DELETE SET NULL,
    estimate_basis_snapshot TEXT,
    status TEXT NOT NULL CHECK(status IN ('needed','bought','skipped')),
    display_order INTEGER NOT NULL CHECK(typeof(display_order)='integer' AND display_order >= 0),
    CHECK((estimate_mode = 'none' AND estimate_total_centavos IS NULL AND source_price_id IS NULL AND estimate_basis_snapshot IS NULL)
      OR (estimate_mode = 'manual' AND estimate_total_centavos IS NOT NULL AND source_price_id IS NULL AND estimate_basis_snapshot IS NULL)
      OR (estimate_mode = 'price' AND estimate_total_centavos IS NOT NULL AND estimate_basis_snapshot IS NOT NULL))
  )''',
  '''CREATE TABLE purchases (
    id TEXT PRIMARY KEY NOT NULL,
    list_item_id TEXT UNIQUE REFERENCES list_items(id) ON DELETE RESTRICT,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    store_id TEXT REFERENCES stores(id) ON DELETE RESTRICT,
    actual_quantity_base INTEGER NOT NULL CHECK(typeof(actual_quantity_base)='integer' AND actual_quantity_base BETWEEN 1 AND 1000000),
    actual_total_centavos INTEGER NOT NULL CHECK(typeof(actual_total_centavos)='integer' AND actual_total_centavos BETWEEN 0 AND 100000000),
    purchased_on TEXT NOT NULL, product_snapshot TEXT NOT NULL, store_snapshot TEXT,
    created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL
  )''',
  '''CREATE TABLE app_settings (
    "key" TEXT PRIMARY KEY NOT NULL, "value" TEXT NOT NULL
  )''',
  '''CREATE TABLE monthly_budgets (
    month TEXT PRIMARY KEY NOT NULL, budget_centavos INTEGER NOT NULL
      CHECK(typeof(budget_centavos)='integer' AND budget_centavos BETWEEN 0 AND 1000000000)
  )''',
  'CREATE INDEX prices_lookup ON price_records(product_id, store_id, observed_on)',
  'CREATE INDEX list_items_list ON list_items(list_id, display_order)',
  'CREATE INDEX purchases_date ON purchases(purchased_on)',
  '''CREATE TRIGGER preserve_quantity_kind BEFORE UPDATE OF quantity_kind ON products
    WHEN NEW.quantity_kind != OLD.quantity_kind AND
      (EXISTS(SELECT 1 FROM price_records WHERE product_id=OLD.id)
        OR EXISTS(SELECT 1 FROM list_items WHERE product_id=OLD.id)
        OR EXISTS(SELECT 1 FROM purchases WHERE product_id=OLD.id))
    BEGIN SELECT RAISE(ABORT, 'Referenced quantity kind cannot change'); END''',
];
