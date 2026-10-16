import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/data/validation.dart';

import 'repository_test.dart' show fixtures, now, purchase, productId, storeId;

void main() {
  late AppRepository repository;
  late Map<String, dynamic> document;
  setUp(() async {
    repository = AppRepository(AppDatabase.memory(), clock: () => now);
    await fixtures(repository);
    await repository.savePurchase(purchase());
    document =
        jsonDecode(encodeBackup(await repository.load(), now: now))
            as Map<String, dynamic>;
  });
  tearDown(() async => repository.close());

  void rejects(void Function(Map<String, dynamic>) mutate) {
    mutate(document);
    expect(
      () => decodeBackup(jsonEncode(document), now: now),
      throwsA(isA<ValidationException>()),
    );
  }

  test(
    'T25 invalid JSON and incompatible envelope reject before mutation',
    () async {
      final before = encodeBackup(await repository.load(), now: now);
      for (final text in ['not json', '[]', '{}']) {
        expect(
          () => decodeBackup(text, now: now),
          throwsA(isA<ValidationException>()),
        );
      }
      rejects((d) => d['format_version'] = 2);
      expect(encodeBackup(await repository.load(), now: now), before);
    },
  );
  test(
    'T25 duplicate IDs reject',
    () => rejects(
      (d) => (d['products'] as List).add((d['products'] as List).first),
    ),
  );
  test(
    'T25 invalid enum rejects',
    () => rejects((d) => d['products'][0]['quantity_kind'] = 'bundle'),
  );
  test('T25 non-integer and excessive quantities reject', () {
    rejects((d) => d['price_records'][0]['offered_quantity_base'] = 1.5);
    document['price_records'][0]['offered_quantity_base'] = 1000001;
    expect(
      () => decodeBackup(jsonEncode(document), now: now),
      throwsA(isA<ValidationException>()),
    );
  });
  test(
    'T25 missing references reject',
    () => rejects((d) => d['stores'] = <dynamic>[]),
  );
  test(
    'T25 unknown fields reject',
    () => rejects((d) => d['products'][0]['remote_owner'] = 'unknown'),
  );
  test('T25 invalid and future calendar dates reject', () {
    rejects((d) => d['purchases'][0]['purchased_on'] = '2026-02-30');
    document['purchases'][0]['purchased_on'] = '2026-10-17';
    expect(
      () => decodeBackup(jsonEncode(document), now: now),
      throwsA(isA<ValidationException>()),
    );
  });
  test('T25 inconsistent estimate/purchase states and snapshots reject', () {
    rejects((d) => d['list_items'][0]['status'] = 'needed');
    document['list_items'][0]['status'] = 'bought';
    document['list_items'][0]['estimate_total_centavos'] = 8999;
    expect(
      () => decodeBackup(jsonEncode(document), now: now),
      throwsA(isA<ValidationException>()),
    );
    document['list_items'][0]['estimate_total_centavos'] = 9000;
    document['purchases'][0]['product_snapshot']['quantity_kind'] = 'volume';
    expect(
      () => decodeBackup(jsonEncode(document), now: now),
      throwsA(isA<ValidationException>()),
    );
  });
  test('T25 byte and aggregate-row caps reject', () {
    expect(
      () => decodeBackup(' ' * (maxBackupBytes + 1), now: now),
      throwsA(isA<ValidationException>()),
    );
    rejects(
      (d) => d['products'] = List.filled(maxBackupRows + 1, d['products'][0]),
    );
  });
  test(
    'T25 snapshot quote and frozen reference mismatch rejects',
    () => rejects(
      (d) =>
          d['list_items'][0]['estimate_basis_snapshot']['quoted_centavos'] = 0,
    ),
  );
  test('T27 formula cells are inert even after whitespace and controls', () {
    for (final value in [
      '=1+1',
      '+SUM(A1)',
      '-1',
      '@SUM(A1)',
      '  =2',
      '\tText',
      '\rText',
      ' \t  abc',
      '\n\tText',
      '  @SUM(A1)',
    ]) {
      expect(
        csvText(value).startsWith('"\''),
        true,
        reason: 'Unsafe cell: ${jsonEncode(value)}',
      );
    }
    expect(csvText('Tomato, "red"\n₱'), '"Tomato, ""red""\n₱"');
    expect(csvText('regular value'), '"regular value"');
  });
  test(
    'T27 price and purchase exports use snapshots and integer centavo columns',
    () async {
      await repository.saveProduct({
        'id': productId,
        'name': ' =HYPERLINK("fictional")',
        'category': 'New category',
      });
      await repository.saveStore({'id': storeId, 'name': '\tFictional stall'});
      final data = await repository.load();
      final prices = pricesCsv(data);
      final purchases = purchasesCsv(data);
      expect(prices, contains('quoted_centavos_PHP'));
      expect(prices, contains("\"' =HYPERLINK(\"\"fictional\"\")\""));
      expect(prices, contains(',4500,500,'));
      expect(purchases, contains('Tomato “sample”'));
      expect(purchases, contains('Vegetables'));
      expect(purchases, contains(',1000,9000,'));
      expect(purchases, isNot(contains('New category')));
    },
  );
}
