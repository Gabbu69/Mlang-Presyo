import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/data/validation.dart';

void main() {
  test(
    'settings and monthly budgets preserve the aggregate portable row limit',
    () async {
      final database = AppDatabase.memory();
      final repository = AppRepository(database);
      addTearDown(repository.close);
      await repository.saveProduct({
        'name': 'Fictional row-limit fixture',
        'quantity_kind': 'count',
      });
      await repository.setMonthlyBudget('2026-10', 0);
      // Populate a boundary fixture in one SQL statement so this test measures
      // validation and transaction behavior, not 19,998 individual UI writes.
      await database.customStatement('''
      WITH RECURSIVE fixture(n) AS (
        SELECT 0 UNION ALL SELECT n + 1 FROM fixture WHERE n < 19997
      )
      INSERT INTO app_settings (key, value)
        SELECT 'fixture_' || n, 'false' FROM fixture
    ''');
      final before = await repository.load();
      expect(before.settings, hasLength(maxBackupRows - 2));
      validateAppData(before);

      await expectLater(
        repository.setSetting('would_exceed_limit', true),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repository.setMonthlyBudget('2026-11', 100),
        throwsA(isA<ValidationException>()),
      );
      final afterFailures = await repository.load();
      expect(afterFailures.settings, before.settings);
      expect(afterFailures.monthlyBudgets, before.monthlyBudgets);
      expect(afterFailures.products, before.products);

      // Updating existing rows at the cap must remain possible.
      await repository.setSetting('fixture_0', true);
      await repository.setMonthlyBudget('2026-10', 100);
      var updated = await repository.load();
      expect(updated.settings['fixture_0'], isTrue);
      expect(updated.monthlyBudgets, {'2026-10': 100});
      expect(updated.settings, hasLength(maxBackupRows - 2));
      validateAppData(updated);

      // Clearing a budget frees exactly one row for a later insertion.
      await repository.setMonthlyBudget('2026-10', null);
      await repository.setMonthlyBudget('2026-11', 0);
      updated = await repository.load();
      expect(updated.monthlyBudgets, {'2026-11': 0});
      validateAppData(updated);
    },
  );
}
