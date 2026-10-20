import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/data/validation.dart';

import 'repository_test.dart' show fixtures, now;

void main() {
  test(
    'valid Unicode notes cannot make a successful write unbackuppable',
    () async {
      final repository = AppRepository(AppDatabase.memory(), clock: () => now);
      addTearDown(repository.close);
      await fixtures(repository);
      final original = await repository.load();
      final before = encodeBackup(original, now: now);
      AppData pricesFixture(int count) => AppData(
        products: original.products,
        stores: original.stores,
        prices: [
          for (var index = 0; index < count; index++)
            {
              ...original.prices.single,
              'id': index == 0
                  ? original.prices.single['id']
                  : '30000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
              'notes': '₱' * 1000,
            },
        ],
        lists: original.lists,
        items: original.items,
        purchases: original.purchases,
        settings: original.settings,
        monthlyBudgets: original.monthlyBudgets,
      );

      // Fixed-length UUIDs make each additional price's serialized size equal.
      // Actual export metadata is 24 chars here; capacity reserves 27 chars.
      final firstBytes = utf8
          .encode(encodeBackup(pricesFixture(1), now: now))
          .length;
      final rowBytes =
          utf8.encode(encodeBackup(pricesFixture(2), now: now)).length -
          firstBytes;
      final count = 1 + (maxBackupBytes - 3 - firstBytes) ~/ rowBytes;
      final tooLarge = pricesFixture(count + 1);
      expect(count, lessThan(maxBackupRows - 5));
      // Every row and field is valid; only the full UTF-8 file capacity fails.
      validateAppData(tooLarge, now: now);
      await expectLater(
        repository.restore(tooLarge),
        throwsA(isA<ValidationException>()),
      );
      expect(encodeBackup(await repository.load(), now: now), before);

      final nearLimit = pricesFixture(count);
      validateBackupCapacity(nearLimit);
      await repository.restore(nearLimit);
      final nearBackup = encodeBackup(await repository.load(), now: now);
      expect(
        utf8.encode(nearBackup).length,
        greaterThan(maxBackupBytes - rowBytes - 3),
      );
      final decoded = decodeBackup(nearBackup, now: now);
      expect(decoded.prices, nearLimit.prices);
      expect(decoded.items, nearLimit.items);
      // Maximum timestamp precision remains fully exportable later as well.
      final laterBackup = encodeBackup(
        await repository.load(),
        now: now.add(const Duration(microseconds: 1)),
      );
      expect(
        utf8.encode(laterBackup).length,
        lessThanOrEqualTo(maxBackupBytes),
      );

      // One individually valid setting is larger than the remaining capacity.
      await expectLater(
        repository.setSetting('would_exceed_bytes', '₱' * 2000),
        throwsA(isA<ValidationException>()),
      );
      expect(encodeBackup(await repository.load(), now: now), nearBackup);
    },
  );
}
