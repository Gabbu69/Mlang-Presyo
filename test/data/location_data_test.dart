import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/location.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/data/validation.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../support/legacy_backup.dart';
import 'repository_test.dart' show fixtures, now, purchase, storeId, itemId;

const storeTag = <String, dynamic>{
  'area_text': 'Sample City',
  'latitude_e6': 7000000,
  'longitude_e6': 125000000,
  'accuracy_m': 1500,
  'location_captured_at_utc': '2026-10-16T05:00:00.000Z',
};

final nearbyArea = ShoppingArea(
  mode: 'nearby',
  label: 'Shopping trip',
  latitudeE6: 7000000,
  longitudeE6: 125000000,
  accuracyM: 1200,
  capturedAtUtc: now,
  radiusM: 25000,
);

AppData _withStores(AppData data, List<Row> stores) => AppData(
  products: data.products,
  stores: stores,
  prices: data.prices,
  lists: data.lists,
  items: data.items,
  purchases: data.purchases,
  settings: data.settings,
  monthlyBudgets: data.monthlyBudgets,
);

void main() {
  late AppRepository repository;
  setUp(() async {
    repository = AppRepository(AppDatabase.memory(), clock: () => now);
    await fixtures(repository);
  });
  tearDown(() => repository.close());

  test(
    'area selection never tags stores or changes frozen estimates and actual spending',
    () async {
      await repository.savePurchase(purchase());
      final before = await repository.load();
      await repository.saveShoppingArea(nearbyArea.toRow());
      final nearby = await repository.load();
      expect(nearby.stores, before.stores);
      expect(nearby.items, before.items);
      expect(nearby.purchases, before.purchases);
      expect(monthlySpent(nearby, '2026-10'), 9000);
      expect(
        listTotals(nearby, before.lists.single['id'] as String).actualSpent,
        9000,
      );
      expect(
        pricesInArea(nearby, ShoppingArea.fromSettings(nearby.settings)),
        isEmpty,
      );
      await repository.saveShoppingArea(
        const ShoppingArea(mode: 'manual', label: 'Sample City').toRow(),
      );
      expect((await repository.load()).stores, before.stores);
      await repository.saveShoppingArea(const ShoppingArea().toRow());
      final all = await repository.load();
      expect(ShoppingArea.fromSettings(all.settings).isAll, true);
      expect(all.settings['area_latitude_e6'], isNull);
      expect(all.items, before.items);
      expect(all.purchases, before.purchases);
    },
  );

  test(
    'explicit store tags and saved area persist on SQLite close/reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'presyo_location_reopen_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/notebook.sqlite');
      var disk = AppRepository(AppDatabase.file(file), clock: () => now);
      try {
        await fixtures(disk);
        await disk.saveStore({'id': storeId, ...storeTag});
        await disk.saveShoppingArea(nearbyArea.toRow());
        final before = encodeBackup(await disk.load(), now: now);
        await disk.close();
        disk = AppRepository(AppDatabase.file(file), clock: () => now);
        expect(encodeBackup(await disk.load(), now: now), before);
        final data = await disk.load();
        expect(
          ShoppingArea.fromSettings(data.settings).toRow(),
          nearbyArea.toRow(),
        );
        expect(pricesInArea(data, nearbyArea), data.prices);
        expect(
          await disk.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await disk.saveStore({
          'id': storeId,
          for (final field in storeLocationFields.where(
            (field) => field != 'area_text',
          ))
            field: null,
        });
        expect((await disk.load()).stores.single['latitude_e6'], isNull);
        expect((await disk.load()).stores.single['area_text'], 'Sample City');
      } finally {
        await disk.close();
      }
    },
  );

  test(
    'failed shopping-area transaction preserves the complete previous selection',
    () async {
      await repository.saveShoppingArea(
        const ShoppingArea(mode: 'manual', label: 'Original area').toRow(),
      );
      final before = encodeBackup(await repository.load(), now: now);
      final failing = AppRepository(
        repository.db,
        clock: () => now,
        writeCheckpoint: (stage) {
          if (stage == 'shopping_area_written') {
            throw StateError('Injected setting failure');
          }
        },
      );
      await expectLater(
        failing.saveShoppingArea(nearbyArea.toRow()),
        throwsStateError,
      );
      expect(encodeBackup(await repository.load(), now: now), before);
    },
  );

  test(
    'signed setting bounds reject minimum-int overflow before writes or restore',
    () async {
      for (final boundary in [-9007199254740991, 9007199254740991]) {
        await repository.setSetting('signed_setting', boundary);
        expect((await repository.load()).settings['signed_setting'], boundary);
      }
      final before = encodeBackup(await repository.load(), now: now);
      for (final invalidValue in [
        -9223372036854775808,
        -9007199254740992,
        9007199254740992,
      ]) {
        expect(
          () => validateSetting('signed_setting', invalidValue),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.setSetting('signed_setting', invalidValue),
          throwsA(isA<ValidationException>()),
        );
        final document = jsonDecode(before) as Row;
        document['app_settings']['signed_setting'] = invalidValue;
        expect(
          () => decodeBackup(jsonEncode(document), now: now),
          throwsA(isA<ValidationException>()),
        );
        expect(encodeBackup(await repository.load(), now: now), before);
      }
    },
  );

  test(
    'location tags stay frozen in estimates and purchase history across edits and backup round-trip',
    () async {
      await repository.saveStore({'id': storeId, ...storeTag});
      await repository.saveItem({
        'id': itemId,
        'estimate_basis_snapshot': null,
      });
      await repository.savePurchase(purchase());
      await repository.saveShoppingArea(nearbyArea.toRow());
      final historical = await repository.load();
      await repository.saveStore({
        'id': storeId,
        ...storeTag,
        'area_text': 'Other city',
        'latitude_e6': 8000000,
      });
      final changed = await repository.load();
      expect(changed.items, historical.items);
      expect(changed.purchases, historical.purchases);
      expect(
        changed.purchases.single['store_snapshot']['area_text'],
        'Sample City',
      );
      expect(
        changed.items.single['estimate_basis_snapshot']['store_latitude_e6'],
        7000000,
      );
      expect(monthlySpent(changed, '2026-10'), 9000);
      final backup = encodeBackup(changed, now: now);
      expect((jsonDecode(backup) as Row)['format_version'], 2);
      final target = AppRepository(AppDatabase.memory(), clock: () => now);
      addTearDown(target.close);
      await target.restore(decodeBackup(backup, now: now));
      expect(encodeBackup(await target.load(), now: now), backup);
    },
  );

  test(
    'format 1 imports with null store tags and unchanged old snapshot shapes, then exports format 2',
    () async {
      await repository.savePurchase(purchase());
      final legacy = legacyBackupDocument(await repository.load(), now: now);
      final restored = decodeBackup(jsonEncode(legacy), now: now);
      expect(restored.stores.single['latitude_e6'], isNull);
      expect(restored.stores.single['area_text'], isNull);
      expect(ShoppingArea.fromSettings(restored.settings).isAll, true);
      expect(
        restored.items.single['estimate_basis_snapshot'],
        legacy['list_items'][0]['estimate_basis_snapshot'],
      );
      expect(
        restored.purchases.single['store_snapshot'],
        legacy['purchases'][0]['store_snapshot'],
      );
      await repository.restore(restored);
      final encoded = encodeBackup(await repository.load(), now: now);
      expect((jsonDecode(encoded) as Row)['format_version'], 2);
      final second = decodeBackup(encoded, now: now);
      expect(
        second.purchases.single['store_snapshot'],
        restored.purchases.single['store_snapshot'],
      );
      await repository.saveStore({'id': storeId, ...storeTag});
      await repository.saveItem({
        'id': itemId,
        'requested_quantity_base': 1250,
      });
      final edited = await repository.load();
      expect(edited.items.single['estimate_total_centavos'], 13500);
      expect(
        edited.purchases.single['store_snapshot'],
        restored.purchases.single['store_snapshot'],
      );
      expect(monthlySpent(edited, '2026-10'), 9000);
    },
  );

  test(
    'malformed store/area/snapshot locations reject before any restore write',
    () async {
      await repository.saveStore({'id': storeId, ...storeTag});
      await repository.saveItem({
        'id': itemId,
        'estimate_basis_snapshot': null,
      });
      await repository.savePurchase(purchase());
      await repository.saveShoppingArea(nearbyArea.toRow());
      final before = encodeBackup(await repository.load(), now: now);
      final changes = <void Function(Row)>[
        (doc) => doc['stores'][0]['latitude_e6'] = 90000001,
        (doc) => doc['stores'][0]['longitude_e6'] = -180000001,
        (doc) => doc['stores'][0]['latitude_e6'] = 7.0,
        (doc) => doc['stores'][0]['accuracy_m'] = null,
        (doc) => doc['stores'][0]['accuracy_m'] = 0,
        (doc) => doc['stores'][0]['accuracy_m'] = 100001,
        (doc) => doc['stores'][0]['location_captured_at_utc'] =
            '2026-02-30T00:00:00Z',
        (doc) => doc['stores'][0]['area_text'] = '  ',
        (doc) => doc['app_settings'].remove('area_radius_m'),
        (doc) => doc['app_settings']['area_radius_m'] = 3000,
        (doc) => doc['app_settings']['location_mode'] = 'unsupported',
        (doc) => doc['app_settings']['location_mode'] = 'all',
        (doc) =>
            doc['app_settings']['area_captured_at_utc'] = '2026-10-16T05:00:00',
        (doc) => doc['purchases'][0]['store_snapshot']['longitude_e6'] = null,
        (doc) => doc['list_items'][0]['estimate_basis_snapshot'].remove(
          'store_accuracy_m',
        ),
      ];
      for (final mutate in changes) {
        final document = jsonDecode(before) as Row;
        mutate(document);
        expect(
          () => decodeBackup(jsonEncode(document), now: now),
          throwsA(isA<ValidationException>()),
        );
      }
      final original = await repository.load();
      var checkpoints = 0;
      final checked = AppRepository(
        repository.db,
        clock: () => now,
        writeCheckpoint: (_) => checkpoints++,
      );
      await expectLater(
        checked.restore(
          _withStores(original, [
            {...original.stores.single, 'accuracy_m': null},
          ]),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(checkpoints, 0);
      expect(encodeBackup(await repository.load(), now: now), before);
    },
  );

  test(
    'failed replacement restore rolls back locations, settings and historical snapshots',
    () async {
      await repository.saveStore({'id': storeId, ...storeTag});
      await repository.saveShoppingArea(nearbyArea.toRow());
      final before = encodeBackup(await repository.load(), now: now);
      await expectLater(
        repository.restore(
          AppData.empty(),
          beforeCommit: () {
            throw StateError('Injected restore failure');
          },
        ),
        throwsStateError,
      );
      expect(encodeBackup(await repository.load(), now: now), before);
    },
  );

  test(
    'database constraints reject partial location tags independently of repository validation',
    () async {
      await expectLater(
        repository.db.customStatement(
          'UPDATE stores SET latitude_e6=7000000 WHERE id=?',
          [storeId],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await repository.saveStore({'id': storeId, ...storeTag});
      await expectLater(
        repository.db.customStatement(
          'UPDATE stores SET accuracy_m=0 WHERE id=?',
          [storeId],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect((await repository.load()).stores.single['accuracy_m'], 1500);
    },
  );

  test(
    'CSV escapes formula-like area labels and includes original location snapshots',
    () async {
      await repository.saveStore({
        'id': storeId,
        ...storeTag,
        'area_text': ' =HYPERLINK("sample")',
      });
      await repository.savePurchase(purchase());
      final data = await repository.load();
      for (final csv in [pricesCsv(data), purchasesCsv(data)]) {
        expect(csv, contains('latitude_e6'));
        expect(csv, contains("\"' =HYPERLINK(\"\"sample\"\")\""));
        expect(csv, contains(',7000000,125000000,1500,'));
      }
    },
  );
}
