import 'dart:convert';
import 'dart:io';

// The pinned Drift version exposes its typed isolate error through this
// experimental library. Keep the exact wrapper and SQLite-cause assertion.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/location.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../data/repository_test.dart'
    show fixtures, now, purchase, productId, storeId, itemId;
import '../generated_migrations/schema.dart';
import '../support/legacy_backup.dart';

void _writeV1File(File file, Row document) {
  final schema =
      jsonDecode(File('drift_schemas/schema_v1.json').readAsStringSync())
          as Row;
  final entities = (schema['entities'] as List).cast<Row>();
  final raw = sqlite.sqlite3.open(file.path);
  try {
    // Use the retained historical schema, not current onCreate with a forged
    // version. Tables must exist before their indexes and triggers.
    for (final type in ['table', 'index', 'trigger']) {
      for (final entity in entities.where((entity) => entity['type'] == type)) {
        raw.execute(entity['sql'] as String);
      }
    }
    raw.execute('PRAGMA foreign_keys = ON');
    for (final table in [
      'products',
      'stores',
      'price_records',
      'shopping_lists',
      'list_items',
      'purchases',
    ]) {
      for (final row in (document[table] as List).cast<Row>()) {
        final fields = row.keys.toList();
        raw.execute(
          'INSERT INTO $table (${fields.join(',')}) VALUES '
          '(${List.filled(fields.length, '?').join(',')})',
          fields.map((field) {
            final value = row[field];
            if (value is bool) return value ? 1 : 0;
            if (value is Map || value is List) return jsonEncode(value);
            return value;
          }).toList(),
        );
      }
    }
    for (final entry in (document['app_settings'] as Row).entries) {
      raw.execute('INSERT INTO app_settings("key","value") VALUES (?,?)', [
        entry.key,
        jsonEncode(entry.value),
      ]);
    }
    for (final row in document['monthly_budgets'] as List) {
      raw.execute(
        'INSERT INTO monthly_budgets(month,budget_centavos) VALUES (?,?)',
        [row['month'], row['budget_centavos']],
      );
    }
    raw.execute('PRAGMA user_version = 1');
  } finally {
    raw.close();
  }
}

void main() {
  late Directory directory;
  late Row legacyDocument;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'presyo_location_migration_',
    );
    final source = AppRepository(AppDatabase.memory(), clock: () => now);
    try {
      await fixtures(source);
      await source.savePurchase(purchase());
      await source.setMonthlyBudget('2026-10', 50000);
      await source.setSetting('onboarding_complete', true);
      await source.saveStore({
        'id': storeId,
        'name': 'Updated fictional stall',
      });
      await source.saveProduct({
        'id': productId,
        'name': 'Updated fictional tomato',
      });
      legacyDocument = legacyBackupDocument(await source.load(), now: now);
    } finally {
      await source.close();
    }
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'actual populated v1 migrates to v2 with unchanged IDs, snapshots, totals and reopen',
    () async {
      final file = File('${directory.path}/legacy.sqlite');
      _writeV1File(file, legacyDocument);
      final expected = decodeBackup(jsonEncode(legacyDocument), now: now);
      var repository = AppRepository(AppDatabase.file(file), clock: () => now);
      try {
        await SchemaVerifier(GeneratedHelper()).migrateAndValidate(
          repository.db,
          2,
          options: const ValidationOptions(validateDropped: true),
        );
        final migrated = await repository.load();
        expect(
          jsonDecode(encodeBackup(migrated, now: now)),
          jsonDecode(encodeBackup(expected, now: now)),
        );
        expect(migrated.stores.single['latitude_e6'], isNull);
        expect(migrated.stores.single['area_text'], isNull);
        expect(ShoppingArea.fromSettings(migrated.settings).isAll, true);
        expect(monthlySpent(migrated, '2026-10'), 9000);
        expect(migrated.items.single['estimate_total_centavos'], 9000);
        expect(
          migrated.purchases.single['store_snapshot']['name'],
          'Fictional stall',
        );
        expect(
          (migrated.purchases.single['store_snapshot'] as Map).containsKey(
            'latitude_e6',
          ),
          false,
        );
        expect(
          (await repository.db.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          2,
        );
        expect(
          (await repository.db.customSelect('PRAGMA foreign_keys').getSingle())
              .data
              .values
              .single,
          1,
        );
        expect(
          await repository.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await expectLater(
          repository.db.customStatement('UPDATE price_records SET store_id=?', [
            productId,
          ]),
          throwsA(
            isA<DriftRemoteException>().having(
              (error) => error.remoteCause.toString(),
              'SQLite constraint failure from the database isolate',
              contains('FOREIGN KEY constraint failed'),
            ),
          ),
        );
        await repository.saveStore({'id': storeId, 'area_text': 'Sample city'});
        await repository.saveShoppingArea(
          const ShoppingArea(mode: 'manual', label: 'Sample city').toRow(),
        );
        final beforeReopen = encodeBackup(await repository.load(), now: now);
        await repository.close();
        repository = AppRepository(AppDatabase.file(file), clock: () => now);
        expect(encodeBackup(await repository.load(), now: now), beforeReopen);
        await repository.saveItem({
          'id': itemId,
          'requested_quantity_base': 1250,
        });
        expect(
          (await repository.load()).items.single['estimate_total_centavos'],
          13500,
        );
        expect(monthlySpent(await repository.load(), '2026-10'), 9000);
      } finally {
        await repository.close();
      }
    },
  );

  test(
    'failure partway through migration rolls back added columns and preserves v1 data',
    () async {
      final file = File('${directory.path}/failed.sqlite');
      _writeV1File(file, legacyDocument);
      var raw = sqlite.sqlite3.open(file.path);
      raw.execute('ALTER TABLE stores ADD COLUMN longitude_e6 INTEGER');
      final beforeSchema = raw
          .select('SELECT name,sql FROM sqlite_master ORDER BY name')
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      final beforeStores = raw
          .select('SELECT * FROM stores')
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      raw.close();
      final database = AppDatabase.file(file);
      try {
        await expectLater(
          database.customSelect('SELECT * FROM stores').get(),
          throwsA(anything),
        );
      } finally {
        await database.close();
      }
      raw = sqlite.sqlite3.open(file.path);
      try {
        expect(raw.select('PRAGMA user_version').single.values.single, 1);
        expect(
          raw
              .select('SELECT name,sql FROM sqlite_master ORDER BY name')
              .map((row) => Map<String, Object?>.from(row))
              .toList(),
          beforeSchema,
        );
        expect(
          raw
              .select('SELECT * FROM stores')
              .map((row) => Map<String, Object?>.from(row))
              .toList(),
          beforeStores,
        );
        expect(
          raw
              .select('SELECT actual_total_centavos FROM purchases')
              .single['actual_total_centavos'],
          9000,
        );
        expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        raw.close();
      }
    },
  );
}
