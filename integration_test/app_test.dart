import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:presyo_mlang/app/app.dart';
import 'package:presyo_mlang/app/controller.dart';
import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';

class IntegrationController extends AppController {
  IntegrationController(this.testRepository);
  final AppRepository testRepository;

  @override
  AppRepository get repository => testRepository;

  @override
  Future<AppData> build() => repository.load();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline SQLite journey survives close/reopen and backup round-trip',
    (tester) async {
      // This unique test-owned directory never opens personal.sqlite or demo.sqlite.
      final temporaryRoot = await getTemporaryDirectory();
      final directory = await temporaryRoot.createTemp('presyo_integration_');
      final file = File('${directory.path}/test_notebook.sqlite');
      AppRepository? active;
      AppRepository? restored;
      addTearDown(() async {
        await active?.close();
        await restored?.close();
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      const product = '20000000-0000-4000-8000-000000000001';
      const store = '20000000-0000-4000-8000-000000000002';
      const price = '20000000-0000-4000-8000-000000000003';
      const list = '20000000-0000-4000-8000-000000000004';
      const item = '20000000-0000-4000-8000-000000000005';
      final now = DateTime.now().toUtc();
      final date = dateText(manilaToday(now));
      final initial = AppRepository(AppDatabase.file(file), clock: () => now);
      active = initial;
      await initial.setSetting('onboarded', true);
      await initial.saveProduct({
        'id': product,
        'name': 'Integration test tomatoes',
        'quantity_kind': 'mass',
        'category': 'Vegetables',
      });
      await initial.saveStore({
        'id': store,
        'name': 'Integration fictional stall',
      });
      await initial.savePrice({
        'id': price,
        'product_id': product,
        'store_id': store,
        'quoted_centavos': 4500,
        'offered_quantity_base': 500,
        'selling_mode': 'packaged',
        'observed_on': date,
      });
      await initial.saveList({
        'id': list,
        'title': 'Integration shopping list',
        'budget_centavos': 50000,
      });
      await initial.saveItem({
        'id': item,
        'list_id': list,
        'product_id': product,
        'requested_quantity_base': 750,
        'estimate_mode': 'price',
        'source_price_id': price,
      });
      await initial.savePurchase({
        'list_item_id': item,
        'product_id': product,
        'store_id': store,
        'actual_quantity_base': 1000,
        'actual_total_centavos': 9000,
        'purchased_on': date,
      });
      final before = await initial.load();
      expect(before.prices.single['quoted_centavos'], 4500);
      expect(listTotals(before, list).actualSpent, 9000);
      expect(listTotals(before, list).remainingEstimate, 0);
      expect(monthlySpent(before, date.substring(0, 7)), 9000);
      final backup = encodeBackup(before, now: now);
      await initial.close();
      active = null;

      final repository = AppRepository(
        AppDatabase.file(file),
        clock: () => now,
      );
      active = repository;
      final reopened = await repository.load();
      expect(encodeBackup(reopened, now: now), backup);
      final restoreRepository = AppRepository(
        AppDatabase.memory(),
        clock: () => now,
      );
      restored = restoreRepository;
      await restoreRepository.restore(decodeBackup(backup, now: now));
      expect(encodeBackup(await restoreRepository.load(), now: now), backup);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appProvider.overrideWith(() => IntegrationController(repository)),
          ],
          child: const PresyoApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Integration shopping list'), findsOneWidget);
      expect(find.text('₱90.00'), findsWidgets);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Spending'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Actual grocery spending'), findsOneWidget);
      expect(find.text('Integration test tomatoes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
