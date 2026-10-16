import 'package:flutter/material.dart' hide Row;
import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/features/common.dart';
import 'package:presyo_mlang/features/prices.dart';

import '../widgets/app_flow_test.dart'
    show mount, reveal, seed, settle, storeId;

String fixtureId(String prefix, int index) =>
    '$prefix-0000-4000-8000-${index.toString().padLeft(12, '0')}';

/// Read the real screen's filtered result children, including lazy cards that
/// are correctly outside the viewport. Visible matches are checked separately.
List<PriceCard> notebookResults(WidgetTester tester) => tester
    .widget<PagePadding>(
      find.descendant(
        of: find.byType(PricesPage),
        matching: find.byType(PagePadding),
      ),
    )
    .children
    .whereType<PriceCard>()
    .toList();

Future<void> chooseFilter(
  WidgetTester tester,
  String label,
  String option,
) async {
  final field = find.widgetWithText(DropdownButtonFormField<String>, label);
  await reveal(tester, field);
  await tester.tap(field);
  await settle(tester);
  await tester.tap(find.text(option).last);
  await settle(tester);
}

void main() {
  testWidgets(
    'HOST ONLY: real Prices search and filters with 2,000 fictional records',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository);
      final base = await repository.load();
      const secondStore = '10000000-0000-4000-8000-000000000005';
      const targetIndex = 1731;
      const targetName = 'Fictional item 1731';
      final observedOn = dateText(manilaToday());
      final timestamp = DateTime.now().toUtc().toIso8601String();

      // One bulk restore uses the real repository/SQLite without measuring
      // fixture setup. All records are invented and this database is in memory.
      await repository.restore(
        AppData(
          products: [
            for (var i = 0; i < 2000; i++)
              {
                ...base.products.single,
                'id': fixtureId('20000000', i),
                'name': 'Fictional item ${i.toString().padLeft(4, '0')}',
                'category': i.isEven
                    ? 'Fictional vegetables'
                    : 'Fictional household',
              },
          ],
          stores: [
            {...base.stores.single, 'name': 'Fictional stall A'},
            {
              ...base.stores.single,
              'id': secondStore,
              'name': 'Fictional stall B',
            },
          ],
          prices: [
            for (var i = 0; i < 2000; i++)
              {
                'id': fixtureId('30000000', i),
                'product_id': fixtureId('20000000', i),
                'store_id': i % 4 < 2 ? storeId : secondStore,
                'quoted_centavos': 1000 + i,
                'offered_quantity_base': 500,
                'selling_mode': 'loose',
                'offer_type': 'regular',
                'source_type': 'observed',
                'observed_on': observedOn,
                'notes': 'Fictional host search fixture',
                'created_at_utc': timestamp,
                'updated_at_utc': timestamp,
              },
          ],
          settings: base.settings,
        ),
      );
      expect((await repository.load()).prices, hasLength(2000));
      await mount(tester, repository, viewport: const Size(390, 844));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Prices'),
        ),
      );
      await settle(tester);
      expect(notebookResults(tester), hasLength(2000));

      final search = find.byType(TextField);
      await reveal(tester, search);
      final elapsed = Stopwatch()..start();
      await tester.enterText(search, targetName);
      await settle(tester);
      final match = find.byWidgetPredicate(
        (widget) =>
            widget is PriceCard &&
            widget.price['id'] == fixtureId('30000000', targetIndex),
      );
      await reveal(tester, match);
      elapsed.stop();
      expect(match, findsOneWidget);
      expect(notebookResults(tester), hasLength(1));
      expect(
        notebookResults(tester).single.price['product_id'],
        fixtureId('20000000', targetIndex),
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        'HOST_WIDGET_SEARCH_ONLY records=2000 products=2000 '
        'unique_search_and_visible_render_ms=${elapsed.elapsedMicroseconds / 1000} '
        '(Flutter widget-test host; includes test pumping/scrolling; '
        'excludes SQLite fixture setup; no Android-device timing claim)',
        wrapWidth: 1024,
      );

      await reveal(tester, search);
      await tester.enterText(search, '');
      await settle(tester);
      expect(notebookResults(tester), hasLength(2000));
      await chooseFilter(tester, 'Category', 'Fictional vegetables');
      expect(notebookResults(tester), hasLength(1000));
      await chooseFilter(tester, 'Store', 'Fictional stall B');
      expect(notebookResults(tester), hasLength(500));

      await reveal(tester, search);
      await tester.enterText(search, targetName.toUpperCase());
      await settle(tester);
      expect(notebookResults(tester), isEmpty);
      expect(find.text('No matching records'), findsOneWidget);
      await chooseFilter(tester, 'Category', 'Fictional household');
      expect(notebookResults(tester), hasLength(1));
      expect(
        notebookResults(tester).single.price['id'],
        fixtureId('30000000', targetIndex),
      );

      await reveal(tester, search);
      await tester.enterText(search, '');
      await settle(tester);
      expect(notebookResults(tester), hasLength(500));
      await chooseFilter(tester, 'Store', 'All stores');
      expect(notebookResults(tester), hasLength(1000));
      await chooseFilter(tester, 'Category', 'All categories');
      expect(notebookResults(tester), hasLength(2000));
      expect(tester.takeException(), isNull);
    },
  );
}
