import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';

const productId = '11111111-1111-4111-8111-111111111111';
const storeId = '22222222-2222-4222-8222-222222222222';
const priceId = '33333333-3333-4333-8333-333333333333';
const listId = '44444444-4444-4444-8444-444444444444';
const itemId = '55555555-5555-4555-8555-555555555555';
const anotherId = '66666666-6666-4666-8666-666666666666';
final now = DateTime.utc(2026, 10, 16, 5);

Future<void> fixtures(AppRepository repository) async {
  await repository.saveProduct({
    'id': productId,
    'name': 'Tomato “sample”',
    'category': 'Vegetables',
    'quantity_kind': 'mass',
  });
  await repository.saveStore({'id': storeId, 'name': 'Fictional stall'});
  await repository.savePrice({
    'id': priceId,
    'product_id': productId,
    'store_id': storeId,
    'quoted_centavos': 4500,
    'offered_quantity_base': 500,
    'selling_mode': 'packaged',
    'observed_on': '2026-10-16',
  });
  await repository.saveList({
    'id': listId,
    'title': 'Weekend list',
    'budget_centavos': 50000,
  });
  await repository.saveItem({
    'id': itemId,
    'list_id': listId,
    'product_id': productId,
    'requested_quantity_base': 750,
    'estimate_mode': 'price',
    'source_price_id': priceId,
  });
}

Row purchase({String? id}) => {
  'id': ?id,
  'list_item_id': itemId,
  'product_id': productId,
  'store_id': storeId,
  'actual_quantity_base': 1000,
  'actual_total_centavos': 9000,
  'purchased_on': '2026-10-16',
};

void main() {
  late AppDatabase database;
  late AppRepository repository;
  setUp(() {
    database = AppDatabase.memory();
    repository = AppRepository(database, clock: () => now);
  });
  tearDown(() async => repository.close());

  test(
    'initial real database is empty, FK enabled and schema is version 2',
    () async {
      final data = await repository.load();
      expect(data.products, isEmpty);
      expect(data.prices, isEmpty);
      expect(data.purchases, isEmpty);
      expect(
        (await database.customSelect('PRAGMA foreign_keys').getSingle())
            .data
            .values
            .single,
        1,
      );
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        2,
      );
      expect(
        (await database.exportedSchema())
            .where((r) => r['type'] == 'table')
            .length,
        8,
      );
    },
  );

  test('initial schema matches the inspected version 2 export', () async {
    final snapshot =
        jsonDecode(await File('drift_schemas/schema_v2.json').readAsString())
            as Map<String, dynamic>;
    expect(snapshot['schema_version'], database.schemaVersion);
    expect(await database.exportedSchema(), snapshot['entities']);
  });

  test(
    'T22 invalid references, invalid enums and DB constraints reject writes',
    () async {
      await fixtures(repository);
      await expectLater(
        repository.savePrice({
          'product_id': anotherId,
          'store_id': storeId,
          'quoted_centavos': 4500,
          'offered_quantity_base': 500,
          'observed_on': '2026-10-16',
        }),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repository.saveProduct({'id': productId, 'quantity_kind': 'volume'}),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repository.savePrice({'id': priceId, 'selling_mode': 'unknown'}),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        database.customStatement(
          "UPDATE price_records SET product_id=? WHERE id=?",
          [anotherId, priceId],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await expectLater(
        database.customStatement(
          'UPDATE price_records SET quoted_centavos=0 WHERE id=?',
          [priceId],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await expectLater(
        database.customStatement(
          'UPDATE price_records SET quoted_centavos=1.5 WHERE id=?',
          [priceId],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await expectLater(
        database.customStatement(
          "UPDATE products SET quantity_kind='volume' WHERE id=?",
          [productId],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await expectLater(
        database.customStatement('DELETE FROM products WHERE id=?', [
          productId,
        ]),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await repository.saveProduct({'id': productId, 'archived': true});
      await repository.saveStore({'id': storeId, 'archived': true});
      final data = await repository.load();
      expect(data.product(productId)['archived'], true);
      expect(data.store(storeId)?['archived'], true);
      expect(data.prices.length, 1);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'T15 concurrent callbacks and retries produce exactly one linked expense',
    () async {
      await fixtures(repository);
      await Future.wait([
        repository.savePurchase(purchase()),
        repository.savePurchase(purchase()),
      ]);
      await repository.savePurchase(purchase(id: anotherId));
      final data = await repository.load();
      expect(data.purchases.length, 1);
      expect(data.items.single['status'], 'bought');
      expect(monthlySpent(data, '2026-10'), 9000);
      expect(listTotals(data, listId).actualSpent, 9000);
      await expectLater(
        repository.saveItem({'id': itemId, 'status': 'needed'}),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repository.deleteItem(itemId),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test(
    'T16 failed purchase save/undo rolls back both ledger and status',
    () async {
      await fixtures(repository);
      final failingSave = AppRepository(
        database,
        clock: () => now,
        writeCheckpoint: (stage) {
          if (stage == 'purchase_written') {
            throw StateError('Injected write failure');
          }
        },
      );
      await expectLater(failingSave.savePurchase(purchase()), throwsStateError);
      var data = await repository.load();
      expect(data.purchases, isEmpty);
      expect(data.items.single['status'], 'needed');
      await repository.savePurchase(purchase());
      final id = (await repository.load()).purchases.single['id'] as String;
      final failingUndo = AppRepository(
        database,
        clock: () => now,
        writeCheckpoint: (stage) {
          if (stage == 'purchase_deleted') {
            throw StateError('Injected undo failure');
          }
        },
      );
      await expectLater(failingUndo.deletePurchase(id), throwsStateError);
      data = await repository.load();
      expect(data.purchases.length, 1);
      expect(data.items.single['status'], 'bought');
      await repository.deletePurchase(id);
      data = await repository.load();
      expect(data.purchases, isEmpty);
      expect(data.items.single['status'], 'needed');
    },
  );

  test(
    'T17 frozen plans and historical snapshots survive catalog and quote edits/deletion',
    () async {
      await fixtures(repository);
      await repository.savePurchase(purchase());
      await repository.saveProduct({
        'id': productId,
        'name': 'Renamed sample',
        'category': 'Other',
      });
      await repository.saveStore({
        'id': storeId,
        'name': 'Renamed sample stall',
      });
      await repository.savePrice({'id': priceId, 'quoted_centavos': 6000});
      var data = await repository.load();
      expect(data.items.single['estimate_total_centavos'], 9000);
      expect(
        data.purchases.single['product_snapshot']['name'],
        'Tomato “sample”',
      );
      expect(categoryTotals(data, '2026-10'), {'Vegetables': 9000});
      await repository.savePurchase({
        'id': data.purchases.single['id'],
        'actual_total_centavos': 8000,
      });
      data = await repository.load();
      expect(
        data.purchases.single['store_snapshot']['name'],
        'Fictional stall',
      );
      expect(data.items.single['requested_quantity_base'], 750);
      expect(data.items.single['estimate_total_centavos'], 9000);
      await repository.deletePrice(priceId);
      data = await repository.load();
      expect(data.items.single['source_price_id'], isNull);
      expect(data.items.single['estimate_total_centavos'], 9000);
      expect(monthlySpent(data, '2026-10'), 8000);
    },
  );

  test(
    'T19 manual quantity edits clear estimates, selected price recalculates frozen basis',
    () async {
      await fixtures(repository);
      await repository.savePrice({'id': priceId, 'quoted_centavos': 8000});
      await repository.saveItem({
        'id': itemId,
        'requested_quantity_base': 1250,
      });
      var data = await repository.load();
      expect(data.items.single['estimate_total_centavos'], 13500);
      await repository.saveItem({
        'id': itemId,
        'estimate_basis_snapshot': null,
      });
      data = await repository.load();
      expect(data.items.single['estimate_total_centavos'], 24000);
      await repository.saveItem({
        'id': itemId,
        'estimate_mode': 'manual',
        'estimate_total_centavos': 1000,
      });
      await repository.saveItem({'id': itemId, 'requested_quantity_base': 500});
      data = await repository.load();
      expect(data.items.single['estimate_mode'], 'none');
      expect(data.items.single['estimate_total_centavos'], isNull);
      await repository.saveItem({
        'id': itemId,
        'estimate_mode': 'manual',
        'estimate_total_centavos': 1200,
      });
      await repository.saveItem({
        'id': itemId,
        'requested_quantity_base': 250,
        'estimate_total_centavos': 600,
      }, confirmManualEstimate: true);
      data = await repository.load();
      expect(data.items.single['estimate_mode'], 'manual');
      expect(data.items.single['estimate_total_centavos'], 600);
    },
  );

  test(
    'T18/T20 monthly dates, duplicate reset and archive preserve ledger',
    () async {
      await fixtures(repository);
      await repository.savePurchase({
        ...purchase(),
        'purchased_on': '2026-09-30',
      });
      await repository.savePurchase({
        'product_id': productId,
        'actual_quantity_base': 50,
        'actual_total_centavos': 0,
        'purchased_on': '2026-10-01',
      });
      final copyId = await repository.duplicateList(listId);
      await repository.saveList({
        'id': listId,
        'status': 'archived',
        'budget_centavos': 0,
      });
      final data = await repository.load();
      final copied = data.listItems(copyId).single;
      expect(copied['id'], isNot(itemId));
      expect(copied['status'], 'needed');
      expect(copied['estimate_total_centavos'], isNull);
      expect(data.purchaseFor(copied['id'] as String), isNull);
      expect(monthlySpent(data, '2026-09'), 9000);
      expect(monthlySpent(data, '2026-10'), 0);
      expect(listTotals(data, listId).budgetLeft, -9000);
      await expectLater(
        repository.savePurchase({...purchase(), 'purchased_on': '2026-10-17'}),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test(
    'changing an unbought product uses a newly selected offer, never an inherited basis',
    () async {
      await fixtures(repository);
      await repository.saveProduct({
        'id': anotherId,
        'name': 'Different fictional product',
        'quantity_kind': 'mass',
      });
      await repository.savePrice({
        'id': '77777777-7777-4777-8777-777777777777',
        'product_id': anotherId,
        'store_id': storeId,
        'quoted_centavos': 1000,
        'offered_quantity_base': 1000,
        'observed_on': '2026-10-16',
      });
      await repository.saveItem({
        'id': itemId,
        'product_id': anotherId,
        'estimate_mode': 'price',
        'source_price_id': '77777777-7777-4777-8777-777777777777',
      });
      final data = await repository.load();
      expect(data.items.single['estimate_total_centavos'], 750);
      expect(
        data.items.single['estimate_basis_snapshot']['product_id'],
        anotherId,
      );
    },
  );

  test(
    'T24 all entities and Unicode round-trip with null and zero budgets',
    () async {
      await fixtures(repository);
      await repository.savePurchase(purchase());
      await repository.savePurchase({
        'product_id': productId,
        'actual_quantity_base': 1,
        'actual_total_centavos': 0,
        'purchased_on': '2026-10-01',
      });
      await repository.saveList({
        'id': anotherId,
        'title': 'Archived “₱” list',
        'status': 'archived',
        'budget_centavos': 0,
      });
      await repository.saveList({
        'id': '77777777-7777-4777-8777-777777777777',
        'title': 'No budget',
      });
      await repository.saveItem({
        'list_id': '77777777-7777-4777-8777-777777777777',
        'product_id': productId,
        'requested_quantity_base': 1,
        'estimate_mode': 'manual',
        'estimate_total_centavos': 0,
      });
      await repository.saveItem({
        'list_id': '77777777-7777-4777-8777-777777777777',
        'product_id': productId,
        'requested_quantity_base': 2,
        'status': 'skipped',
      });
      await repository.saveProduct({'id': productId, 'archived': true});
      await repository.saveStore({'id': storeId, 'archived': true});
      await repository.setSetting('onboarding_complete', true);
      await repository.setSetting('optional_setting', null);
      await repository.setMonthlyBudget('2026-10', 0);
      final before = encodeBackup(await repository.load(), now: now);
      final decoded = decodeBackup(before, now: now);
      final other = AppRepository(AppDatabase.memory(), clock: () => now);
      addTearDown(other.close);
      await other.restore(decoded);
      expect(
        jsonDecode(encodeBackup(await other.load(), now: now)),
        jsonDecode(before),
      );
      expect(
        await other.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'T26 replacement restore errors before commit and halfway preserve every old record',
    () async {
      await fixtures(repository);
      await repository.savePurchase(purchase());
      final before = encodeBackup(await repository.load(), now: now);
      final empty = AppData.empty();
      await expectLater(
        repository.restore(
          empty,
          beforeCommit: () => throw StateError('Injected restore failure'),
        ),
        throwsStateError,
      );
      expect(encodeBackup(await repository.load(), now: now), before);
      final failing = AppRepository(
        database,
        clock: () => now,
        writeCheckpoint: (stage) {
          if (stage == 'restore_price_records') {
            throw StateError('Halfway restore failure');
          }
        },
      );
      await expectLater(
        failing.restore(decodeBackup(before, now: now)),
        throwsStateError,
      );
      expect(encodeBackup(await repository.load(), now: now), before);
    },
  );

  test(
    'T29 demo seed and reset affect only their own isolated database',
    () async {
      await expectLater(
        repository.seedDemo(),
        throwsA(isA<ValidationException>()),
      );
      final demo = AppRepository(
        AppDatabase.memory(),
        demo: true,
        clock: () => now,
      );
      addTearDown(demo.close);
      await demo.seedDemo();
      await demo.seedDemo();
      expect((await demo.load()).prices.length, 2);
      expect((await repository.load()).prices, isEmpty);
      await expectLater(
        demo.restore(AppData.empty()),
        throwsA(isA<ValidationException>()),
      );
      await fixtures(repository);
      await demo.reset();
      expect((await demo.load()).prices, isEmpty);
      expect((await repository.load()).prices.length, 1);
      await repository.savePurchase(purchase());
      await repository.setMonthlyBudget('2026-10', 0);
      await repository.setSetting('onboarding_complete', true);
      await repository.reset();
      final data = await repository.load();
      expect(data.products, isEmpty);
      expect(data.items, isEmpty);
      expect(data.stores, isEmpty);
      expect(data.lists, isEmpty);
      expect(data.prices, isEmpty);
      expect(data.purchases, isEmpty);
      expect(data.settings, isEmpty);
      expect(data.monthlyBudgets, isEmpty);
    },
  );

  test(
    'T21 host SQLite close/reopen retains complete logical records',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presyo_restart_',
      );
      addTearDown(() async => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}notebook.sqlite',
      );
      var disk = AppRepository(AppDatabase.file(file), clock: () => now);
      await fixtures(disk);
      await disk.savePurchase(purchase());
      final before = encodeBackup(await disk.load(), now: now);
      await disk.close();
      disk = AppRepository(AppDatabase.file(file), clock: () => now);
      expect(encodeBackup(await disk.load(), now: now), before);
      expect(
        await disk.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      await disk.close();
    },
  );

  test(
    'unknown future schema does not destructively recreate the database',
    () async {
      final directory = await Directory.systemTemp.createTemp('presyo_schema_');
      addTearDown(() async => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}notebook.sqlite',
      );
      var disk = AppRepository(AppDatabase.file(file), clock: () => now);
      await fixtures(disk);
      await disk.savePurchase(purchase());
      await disk.db.customStatement('PRAGMA user_version = 3');
      await disk.close();
      disk = AppRepository(AppDatabase.file(file), clock: () => now);
      await expectLater(disk.load(), throwsA(anything));
      await disk.close();
      // Inspect the file independently after the refused downgrade, proving
      // populated records and amounts survive the failed open.
      expect(await file.exists(), true);
      final raw = sqlite.sqlite3.open(file.path);
      try {
        expect(raw.select('SELECT id FROM products').single['id'], productId);
        expect(
          raw
              .select(
                'SELECT SUM(actual_total_centavos) AS spent FROM purchases',
              )
              .single['spent'],
          9000,
        );
        expect(
          raw.select('SELECT status FROM list_items').single['status'],
          'bought',
        );
        expect(raw.select('PRAGMA user_version').single.values.single, 3);
        expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        raw.close();
      }
    },
  );
}
