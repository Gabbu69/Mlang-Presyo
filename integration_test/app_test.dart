import 'dart:io';

import 'package:flutter/material.dart' hide Row;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:presyo_mlang/app/app.dart';
import 'package:presyo_mlang/app/controller.dart';
import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/location.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/features/common.dart';
import 'package:presyo_mlang/features/prices.dart';

class IntegrationController extends AppController {
  IntegrationController(this.testRepository);
  final AppRepository testRepository;

  @override
  AppRepository get repository => testRepository;

  @override
  Future<AppData> build() => repository.load();
}

String _fixtureId(String prefix, int index) =>
    '$prefix-0000-4000-8000-${index.toString().padLeft(12, '0')}';

List<PriceCard> _priceResults(WidgetTester tester) => tester
    .widget<PagePadding>(
      find.descendant(
        of: find.byType(PricesPage),
        matching: find.byType(PagePadding),
      ),
    )
    .children
    .whereType<PriceCard>()
    .toList();

Future<void> _revealPriceControl(WidgetTester tester, Finder target) async {
  final list = find
      .descendant(of: find.byType(PricesPage), matching: find.byType(ListView))
      .first;
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(position.minScrollExtent);
  await tester.pump();
  await tester.scrollUntilVisible(
    target,
    160,
    scrollable: scrollable,
    maxScrolls: 80,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .4);
  await tester.pumpAndSettle();
}

Future<void> _enterSearch(WidgetTester tester, String value) async {
  final search = find.byType(TextField);
  await _revealPriceControl(tester, search);
  await _replaceSearchText(tester, search, value);
}

Future<void> _replaceSearchText(
  WidgetTester tester,
  Finder search,
  String value,
) async {
  final editable = find.descendant(
    of: search,
    matching: find.byType(EditableText),
  );
  // IntegrationTest keeps the real IME. Unlike the registered host stub, its
  // clearClient does not reset binding.focusedEditable after unfocus. Reopen
  // explicitly because showKeyboard can see the same state and skip refocus.
  tester.state<EditableTextState>(editable).requestKeyboard();
  await tester.pump();
  await tester.enterText(search, value);
  await tester.pump();
  expect(tester.widget<EditableText>(editable).controller.text, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  expect(tester.widget<EditableText>(editable).controller.text, value);
}

Future<void> _chooseFilter(
  WidgetTester tester,
  String label,
  String option,
) async {
  final field = find.widgetWithText(DropdownButtonFormField<String>, label);
  await _revealPriceControl(tester, field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
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
        'area_text': 'Fictional travel area',
        'latitude_e6': 7000000,
        'longitude_e6': 125000000,
        'accuracy_m': 25,
        'location_captured_at_utc': now.toIso8601String(),
      });
      await initial.saveShoppingArea(
        ShoppingArea(
          mode: 'nearby',
          latitudeE6: 7000000,
          longitudeE6: 125000000,
          accuracyM: 1500,
          capturedAtUtc: now,
        ).toRow(),
      );
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
      expect(ShoppingArea.fromSettings(reopened.settings).radiusM, 10000);
      expect(reopened.stores.single['area_text'], 'Fictional travel area');
      expect(
        pricesInArea(reopened, ShoppingArea.fromSettings(reopened.settings)),
        hasLength(1),
      );
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

  testWidgets(
    'phone Prices search and filters handle 2,000 isolated fictional records',
    (tester) async {
      // A separate test-owned file and controller never open the normal app's
      // personal/demo notebooks. Gradle gives this harness its own app ID.
      final temporaryRoot = await getTemporaryDirectory();
      final directory = await temporaryRoot.createTemp('presyo_search_');
      final repository = AppRepository(
        AppDatabase.file(File('${directory.path}/search_fixture.sqlite')),
      );
      addTearDown(() async {
        await repository.close();
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      const firstStore = '40000000-0000-4000-8000-000000000001';
      const secondStore = '40000000-0000-4000-8000-000000000002';
      const targetIndex = 1731;
      const targetName = 'Fictional item 1731';
      final now = DateTime.now().toUtc();
      final observedOn = dateText(manilaToday(now));
      final timestamp = now.toIso8601String();
      await repository.restore(
        AppData(
          products: [
            for (var index = 0; index < 2000; index++)
              {
                'id': _fixtureId('50000000', index),
                'name': 'Fictional item ${index.toString().padLeft(4, '0')}',
                'brand': '',
                'variant_grade': '',
                'category': index.isEven
                    ? 'Fictional vegetables'
                    : 'Fictional household',
                'quantity_kind': 'mass',
                'archived': false,
                'created_at_utc': timestamp,
                'updated_at_utc': timestamp,
              },
          ],
          stores: [
            for (final entry in {
              firstStore: 'Fictional stall A',
              secondStore: 'Fictional stall B',
            }.entries)
              {
                'id': entry.key,
                'name': entry.value,
                'barangay_text': null,
                'landmark': null,
                'area_text': null,
                'latitude_e6': null,
                'longitude_e6': null,
                'accuracy_m': null,
                'location_captured_at_utc': null,
                'archived': false,
                'created_at_utc': timestamp,
                'updated_at_utc': timestamp,
              },
          ],
          prices: [
            for (var index = 0; index < 2000; index++)
              {
                'id': _fixtureId('60000000', index),
                'product_id': _fixtureId('50000000', index),
                'store_id': index % 4 < 2 ? firstStore : secondStore,
                'quoted_centavos': 1000 + index,
                'offered_quantity_base': 500,
                'selling_mode': 'loose',
                'offer_type': 'regular',
                'source_type': 'observed',
                'observed_on': observedOn,
                'notes': 'Fictional physical-device search fixture',
                'created_at_utc': timestamp,
                'updated_at_utc': timestamp,
              },
          ],
          settings: {'onboarded': true},
        ),
      );
      final fixture = await repository.load();
      expect(fixture.products, hasLength(2000));
      expect(fixture.prices, hasLength(2000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appProvider.overrideWith(() => IntegrationController(repository)),
          ],
          child: const PresyoApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Prices'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_priceResults(tester), hasLength(2000));

      final search = find.byType(TextField);
      await _revealPriceControl(tester, search);
      final elapsed = Stopwatch()..start();
      await _replaceSearchText(tester, search, targetName);
      final matchingCard = find.byWidgetPredicate(
        (widget) =>
            widget is PriceCard &&
            widget.price['id'] == _fixtureId('60000000', targetIndex),
      );
      await _revealPriceControl(tester, matchingCard);
      elapsed.stop();
      expect(matchingCard, findsOneWidget);
      expect(_priceResults(tester), hasLength(1));
      expect(
        _priceResults(tester).single.price['product_id'],
        _fixtureId('50000000', targetIndex),
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        'PHONE_WIDGET_SEARCH_ONLY records=2000 products=2000 '
        'unique_search_and_visible_render_ms=${elapsed.elapsedMicroseconds / 1000} '
        '(physical Android Flutter integration test; includes test pumping, '
        'focus dismissal and scrolling; excludes SQLite fixture setup; '
        'no standalone frame-time or production startup benchmark)',
        wrapWidth: 1024,
      );

      await _revealPriceControl(tester, search);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        targetName,
        reason:
            'Scrolling the result must not discard the visible search query.',
      );
      await _enterSearch(tester, '');
      expect(_priceResults(tester), hasLength(2000));
      await _chooseFilter(tester, 'Category', 'Fictional vegetables');
      expect(_priceResults(tester), hasLength(1000));
      await _chooseFilter(tester, 'Store', 'Fictional stall B');
      expect(_priceResults(tester), hasLength(500));
      await _enterSearch(tester, targetName.toUpperCase());
      expect(_priceResults(tester), isEmpty);
      expect(find.text('No matching records'), findsOneWidget);
      await _chooseFilter(tester, 'Category', 'Fictional household');
      expect(_priceResults(tester), hasLength(1));
      expect(
        _priceResults(tester).single.price['id'],
        _fixtureId('60000000', targetIndex),
      );
      await _enterSearch(tester, '');
      expect(_priceResults(tester), hasLength(500));
      await _chooseFilter(tester, 'Store', 'All stores');
      expect(_priceResults(tester), hasLength(1000));
      await _chooseFilter(tester, 'Category', 'All categories');
      expect(_priceResults(tester), hasLength(2000));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
