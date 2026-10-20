import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';

import 'repository_test.dart' show fixtures, now, priceId, itemId, anotherId;

void main() {
  late AppRepository repository;
  late String completeBackup;
  setUp(() async {
    repository = AppRepository(AppDatabase.memory(), clock: () => now);
    await fixtures(repository);
    completeBackup = encodeBackup(await repository.load(), now: now);
  });
  tearDown(() => repository.close());

  Row backupDocument() => jsonDecode(completeBackup) as Row;
  Row basis(Row document) =>
      document['list_items'][0]['estimate_basis_snapshot'] as Row;

  test(
    'format 2 requires every field of the exported selected-price basis',
    () {
      final fields = basis(backupDocument()).keys.toList();
      for (final field in fields) {
        final document = backupDocument();
        basis(document).remove(field);
        expect(
          () => decodeBackup(jsonEncode(document), now: now),
          throwsA(isA<ValidationException>()),
          reason: 'Missing selected-price snapshot field: $field',
        );
      }
      // Empty brand/variant values remain meaningful, present fields.
      final restored = decodeBackup(completeBackup, now: now);
      expect(restored.items.single['estimate_basis_snapshot']['brand'], '');
      expect(
        restored.items.single['estimate_basis_snapshot']['variant_grade'],
        '',
      );
    },
  );

  test(
    'selected-price basis rejects mismatched identity and quantity kind',
    () {
      for (final changed in <Row>[
        {'product_id': anotherId},
        {'quantity_kind': 'volume'},
        {'offer_type': 'unknown'},
        {'source_type': 'unknown'},
        {'store_id': 'not-a-uuid'},
        {'brand': null},
        {'variant_grade': null},
      ]) {
        final document = backupDocument();
        basis(document).addAll(changed);
        expect(
          () => decodeBackup(jsonEncode(document), now: now),
          throwsA(isA<ValidationException>()),
          reason:
              'Malformed selected-price snapshot field: ${changed.keys.single}',
        );
      }
    },
  );

  test('a deleted source preserves a complete portable frozen basis', () async {
    final original = (await repository.load()).items.single;
    await repository.deletePrice(priceId);
    final detached = await repository.load();
    expect(detached.items.single['source_price_id'], isNull);
    expect(
      detached.items.single['estimate_basis_snapshot'],
      original['estimate_basis_snapshot'],
    );
    final other = AppRepository(AppDatabase.memory(), clock: () => now);
    addTearDown(other.close);
    await other.restore(
      decodeBackup(encodeBackup(detached, now: now), now: now),
    );
    await other.saveItem({'id': itemId, 'requested_quantity_base': 1250});
    final reopened = await other.load();
    expect(reopened.prices, isEmpty);
    expect(reopened.items.single['source_price_id'], isNull);
    expect(reopened.items.single['estimate_total_centavos'], 13500);
    expect(
      reopened.items.single['estimate_basis_snapshot'],
      original['estimate_basis_snapshot'],
    );
  });
}
