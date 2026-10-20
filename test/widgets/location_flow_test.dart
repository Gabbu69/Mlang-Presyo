import 'dart:async';

import 'package:flutter/material.dart' hide Row;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/app/controller.dart';
import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/location.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/features/catalog.dart';
import 'package:presyo_mlang/features/home.dart';
import 'package:presyo_mlang/features/lists.dart';
import 'package:presyo_mlang/features/location.dart';
import 'package:presyo_mlang/features/prices.dart';
import 'package:presyo_mlang/platform/location_service.dart';

import 'app_flow_test.dart' as helpers;

const _otherStore = '20000000-0000-4000-8000-000000000001';
const _localName = 'Fictional local stall';
const _otherName = 'Fictional other stall';

LocationFix _fix({int accuracy = 1500}) => LocationFix(
  latitudeE6: 7000000,
  longitudeE6: 125000000,
  accuracyM: accuracy,
  capturedAtUtc: DateTime.now().toUtc(),
);

class _ControlledLocation extends LocationService {
  _ControlledLocation(this.result);
  final Future<LocationFix> Function() result;
  int calls = 0;

  @override
  Future<LocationFix> currentLocation() {
    calls++;
    return result();
  }
}

class _AreaRepository extends AppRepository {
  _AreaRepository(super.db);
  bool failNextArea = false;
  Completer<void>? holdArea;
  int areaWrites = 0;

  @override
  Future<void> saveShoppingArea(Row area) async {
    areaWrites++;
    if (failNextArea) {
      failNextArea = false;
      throw StateError('Injected shopping-area write failure.');
    }
    await holdArea?.future;
    await super.saveShoppingArea(area);
  }
}

Future<void> _seedScoped(
  AppRepository repository, {
  bool emptyArea = false,
}) async {
  await helpers.seed(repository, shoppingList: true);
  await repository.saveStore({
    'id': helpers.storeId,
    'name': _localName,
    'area_text': '  Davao   City ',
    'latitude_e6': 7000000,
    'longitude_e6': 125000000,
    'accuracy_m': 10,
    'location_captured_at_utc': DateTime.now().toUtc().toIso8601String(),
  });
  await repository.saveStore({
    'id': _otherStore,
    'name': _otherName,
    'area_text': 'Another city',
  });
  for (final (store, price) in [(helpers.storeId, 4500), (_otherStore, 3500)]) {
    await repository.savePrice({
      'product_id': helpers.productId,
      'store_id': store,
      'quoted_centavos': price,
      'offered_quantity_base': 500,
      'selling_mode': 'packaged',
      'observed_on': dateText(manilaToday()),
    });
  }
  await repository.saveShoppingArea(
    ShoppingArea(
      mode: 'manual',
      label: emptyArea ? 'No recorded city' : 'davao city',
    ).toRow(),
  );
}

Future<void> _selectArea(WidgetTester tester, String value) async {
  final dropdown = find.widgetWithText(
    DropdownButtonFormField<String>,
    'Show recorded prices from',
  );
  await helpers.reveal(tester, dropdown);
  await tester.tap(dropdown);
  await helpers.settle(tester);
  final choice = find.byWidgetPredicate(
    (widget) => widget is DropdownMenuItem<String> && widget.value == value,
  );
  await tester.tap(choice.last);
  await helpers.settle(tester);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await helpers.reveal(tester, finder);
  await tester.tap(finder);
  await helpers.settle(tester);
}

Future<void> _allAreas(WidgetTester tester) =>
    _tapVisible(tester, find.widgetWithText(SwitchListTile, 'Show all areas'));

void main() {
  testWidgets(
    'startup and opening shopping-area settings never request location',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await helpers.seed(repository);
      var nativeCalls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(LocationService.channel, (_) async {
        nativeCalls++;
        throw PlatformException(code: 'denied');
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(LocationService.channel, null),
      );
      await helpers.mount(tester, repository);
      expect(nativeCalls, 0);
      await _tapVisible(tester, find.text('Change shopping area').first);
      expect(find.byType(ShoppingAreaPage), findsOneWidget);
      expect(nativeCalls, 0);
      await _tapVisible(tester, find.text('Use my location'));
      expect(nativeCalls, 1);
      expect(find.textContaining('not granted'), findsOneWidget);
    },
  );

  testWidgets(
    'new fix is previewed and cancel preserves the previous saved area and store tags',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await _seedScoped(repository);
      final before = await repository.load();
      final service = _ControlledLocation(() async => _fix());
      await helpers.mount(
        tester,
        repository,
        form: ShoppingAreaPage(locationService: service),
      );
      expect(service.calls, 0);
      await _tapVisible(tester, find.text('Use my location'));
      expect(service.calls, 1);
      await helpers.reveal(tester, find.textContaining('7.000000, 125.000000'));
      expect(find.textContaining('1500'), findsOneWidget);
      expect(find.textContaining('Captured:'), findsOneWidget);
      final radius = tester.widget<DropdownButtonFormField<int>>(
        find.byType(DropdownButtonFormField<int>),
      );
      expect(radius.initialValue, 10000);
      expect((await repository.load()).settings, before.settings);
      await tester.pageBack();
      await helpers.settle(tester);
      final after = await repository.load();
      expect(after.settings, before.settings);
      expect(after.stores, before.stores);
    },
  );

  testWidgets(
    'duplicate capture and Save taps produce one explicit location and one area write',
    (tester) async {
      final repository = _AreaRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await helpers.seed(repository);
      final pending = Completer<LocationFix>();
      final service = _ControlledLocation(() => pending.future);
      await helpers.mount(
        tester,
        repository,
        form: ShoppingAreaPage(locationService: service),
      );
      final locate = find.text('Use my location');
      await helpers.reveal(tester, locate);
      await tester.tap(locate);
      await tester.tap(locate);
      await tester.pump();
      expect(service.calls, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // The capture's busy guard deliberately absorbs this attempted Save.
      await tester.tap(find.text('Saving…'), warnIfMissed: false);
      await tester.pump();
      expect(repository.areaWrites, 0);
      pending.complete(_fix(accuracy: 4));
      await helpers.settle(tester);
      repository.holdArea = Completer<void>();
      await tester.tap(find.text('Save shopping area'));
      await tester.tap(find.text('Save shopping area'));
      await tester.pump();
      expect(repository.areaWrites, 1);
      repository.holdArea!.complete();
      await helpers.settle(tester);
      final saved = await repository.load();
      final area = ShoppingArea.fromSettings(saved.settings);
      expect(area.isNearby, isTrue);
      expect(area.accuracyM, 4);
      expect(
        area.label,
        isEmpty,
        reason: 'Phone coordinates must not invent a city name.',
      );
      expect(
        saved.stores.single['latitude_e6'],
        isNull,
        reason: 'Saving the shopping center must not tag an existing store.',
      );
    },
  );

  testWidgets(
    'failed area Save retains the draft and previous setting for retry',
    (tester) async {
      final repository = _AreaRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await helpers.seed(repository);
      await repository.saveShoppingArea(
        const ShoppingArea(mode: 'manual', label: 'Saved city').toRow(),
      );
      final before = (await repository.load()).settings;
      repository.failNextArea = true;
      await helpers.mount(tester, repository, form: const ShoppingAreaPage());
      await helpers.enter(tester, 'City or municipality', 'New city');
      await tester.tap(find.text('Save shopping area'));
      await helpers.settle(tester);
      expect(find.byType(ShoppingAreaPage), findsOneWidget);
      expect((await repository.load()).settings, before);
      await helpers.expectDraft(tester, 'City or municipality', 'New city');
      await tester.pump(const Duration(seconds: 8));
      await helpers.settle(tester);
      await tester.tap(find.text('Save shopping area'));
      await helpers.settle(tester);
      expect(
        ShoppingArea.fromSettings((await repository.load()).settings).label,
        'New city',
      );
      expect(find.byType(ShoppingAreaPage), findsNothing);
    },
  );

  for (final code in ['denied', 'disabled', 'timeout', 'canceled']) {
    testWidgets(
      '$code capture leaves saved area intact and manual fallback can be saved',
      (tester) async {
        final repository = AppRepository(AppDatabase.memory());
        addTearDown(repository.close);
        await helpers.seed(repository);
        await repository.saveShoppingArea(
          const ShoppingArea(mode: 'manual', label: 'Saved city').toRow(),
        );
        final before = (await repository.load()).settings;
        final service = _ControlledLocation(
          () async => throw LocationException(
            code,
            'Location $code. Enter the location manually.',
          ),
        );
        await helpers.mount(
          tester,
          repository,
          form: ShoppingAreaPage(locationService: service),
        );
        await _tapVisible(tester, find.text('Use my location'));
        expect((await repository.load()).settings, before);
        expect(service.calls, 1);
        await _tapVisible(tester, find.text('Enter area manually'));
        await helpers.enter(tester, 'City or municipality', 'Fallback city');
        await tester.tap(find.text('Save shopping area'));
        await helpers.settle(tester);
        expect(
          ShoppingArea.fromSettings((await repository.load()).settings).label,
          'Fallback city',
        );
        expect(service.calls, 1);
      },
    );
  }

  testWidgets(
    'Retry is explicit and Use all areas remains a draft until Save',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await helpers.seed(repository);
      await repository.saveShoppingArea(
        const ShoppingArea(mode: 'manual', label: 'Saved city').toRow(),
      );
      final before = (await repository.load()).settings;
      final service = _ControlledLocation(
        () async => throw const LocationException(
          'disabled',
          'Location is turned off. Enter the location manually.',
        ),
      );
      await helpers.mount(
        tester,
        repository,
        form: ShoppingAreaPage(locationService: service),
      );
      await _tapVisible(tester, find.text('Use my location'));
      expect(service.calls, 1);
      await _tapVisible(tester, find.text('Retry location'));
      expect(service.calls, 2);
      await _tapVisible(tester, find.text('Use all areas'));
      expect((await repository.load()).settings, before);
      await tester.tap(find.text('Save shopping area'));
      await helpers.settle(tester);
      expect(
        ShoppingArea.fromSettings((await repository.load()).settings).isAll,
        isTrue,
      );
      expect(service.calls, 2);
    },
  );

  testWidgets(
    'manual area requires a visible label and cancellation makes no write',
    (tester) async {
      final repository = _AreaRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await helpers.seed(repository);
      await helpers.mount(tester, repository, form: const ShoppingAreaPage());
      await _selectArea(tester, 'manual');
      await tester.tap(find.text('Save shopping area'));
      await helpers.settle(tester);
      await helpers.reveal(tester, find.text('Enter a city or municipality.'));
      expect(repository.areaWrites, 0);
      await tester.pageBack();
      await helpers.settle(tester);
      expect(
        ShoppingArea.fromSettings((await repository.load()).settings).isAll,
        isTrue,
      );
    },
  );

  testWidgets(
    'store location is an explicit draft and both tagging and removing require Save',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await helpers.seed(repository);
      final original = (await repository.load()).stores.single;
      final service = _ControlledLocation(() async => _fix(accuracy: 6));
      await helpers.mount(
        tester,
        repository,
        form: CatalogForm(
          product: false,
          existing: original,
          locationService: service,
        ),
      );
      expect(service.calls, 0);
      await _tapVisible(
        tester,
        find.text('Tag this store with my current location'),
      );
      expect(service.calls, 1);
      expect((await repository.load()).stores.single['latitude_e6'], isNull);
      await tester.pageBack();
      await helpers.settle(tester);
      expect((await repository.load()).stores.single, original);

      await tester.tap(find.text('Open test form'));
      await helpers.settle(tester);
      await helpers.enter(
        tester,
        'City or municipality (optional)',
        'Tag city',
      );
      await _tapVisible(
        tester,
        find.text('Tag this store with my current location'),
      );
      await tester.tap(find.text('Save'));
      await helpers.settle(tester);
      final tagged = (await repository.load()).stores.single;
      expect(tagged['latitude_e6'], 7000000);
      expect(tagged['longitude_e6'], 125000000);
      expect(tagged['accuracy_m'], 6);
      expect(tagged['area_text'], 'Tag city');

      await helpers.mount(
        tester,
        repository,
        form: CatalogForm(
          product: false,
          existing: tagged,
          locationService: service,
        ),
      );
      await _tapVisible(tester, find.text('Remove location tag'));
      expect((await repository.load()).stores.single, tagged);
      await tester.pageBack();
      await helpers.settle(tester);
      expect((await repository.load()).stores.single, tagged);
      await tester.tap(find.text('Open test form'));
      await helpers.settle(tester);
      await _tapVisible(tester, find.text('Remove location tag'));
      await tester.tap(find.text('Save'));
      await helpers.settle(tester);
      final removed = (await repository.load()).stores.single;
      expect(removed['latitude_e6'], isNull);
      expect(removed['longitude_e6'], isNull);
      expect(removed['accuracy_m'], isNull);
      expect(removed['location_captured_at_utc'], isNull);
      expect(removed['area_text'], 'Tag city');
      expect(
        service.calls,
        2,
        reason: 'Opening or removing a tag must not start capture.',
      );
    },
  );

  testWidgets('failed store recapture preserves its previous saved GPS tag', (
    tester,
  ) async {
    final repository = AppRepository(AppDatabase.memory());
    addTearDown(repository.close);
    await _seedScoped(repository);
    final original = (await repository.load()).store(helpers.storeId)!;
    final service = _ControlledLocation(
      () async => throw const LocationException(
        'denied',
        'Location permission was not granted. Enter the location manually.',
      ),
    );
    await helpers.mount(
      tester,
      repository,
      form: CatalogForm(
        product: false,
        existing: original,
        locationService: service,
      ),
    );
    await _tapVisible(
      tester,
      find.text('Tag this store with my current location'),
    );
    expect(service.calls, 1);
    expect(find.text('Retry store location'), findsOneWidget);
    expect((await repository.load()).store(helpers.storeId), original);
    await _tapVisible(
      tester,
      find.text('Continue without changing the GPS tag'),
    );
    await tester.tap(find.text('Save'));
    await helpers.settle(tester);
    final saved = (await repository.load()).store(helpers.storeId)!;
    for (final field in [
      'latitude_e6',
      'longitude_e6',
      'accuracy_m',
      'location_captured_at_utc',
    ]) {
      expect(saved[field], original[field]);
    }
    expect(service.calls, 1);
  });

  for (final (name, page) in <(String, Widget)>[
    ('Home recent records', const HomePage()),
    ('price browsing', const PricesPage()),
    (
      'product comparison and history',
      const ProductDetail(productId: helpers.productId),
    ),
  ]) {
    testWidgets(
      '$name scopes records and its All areas override never changes saved settings',
      (tester) async {
        final repository = AppRepository(AppDatabase.memory());
        addTearDown(repository.close);
        await _seedScoped(repository);
        final before = (await repository.load()).settings;
        await helpers.mount(
          tester,
          repository,
          form: name == 'product comparison and history'
              ? page
              : Scaffold(body: page),
          viewport: const Size(420, 1800),
        );
        await helpers.reveal(tester, find.text(_localName).first);
        expect(find.text(_otherName), findsNothing);
        expect(find.textContaining('Area: davao city'), findsWidgets);
        await _allAreas(tester);
        await helpers.reveal(tester, find.text(_otherName).first);
        expect(find.text(_otherName), findsWidgets);
        expect((await repository.load()).settings, before);
        await _allAreas(tester);
        await helpers.reveal(tester, find.text(_localName).first);
        expect(find.text(_otherName), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty area shows recovery actions and nearby explains untagged stores',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await _seedScoped(repository, emptyArea: true);
      await helpers.mount(
        tester,
        repository,
        form: const Scaffold(body: PricesPage()),
        viewport: const Size(420, 1800),
      );
      await helpers.reveal(
        tester,
        find.text('You haven’t recorded prices in this area yet'),
      );
      expect(find.text('Add store'), findsOneWidget);
      expect(find.text('Add price'), findsWidgets);
      await _allAreas(tester);
      await helpers.reveal(tester, find.text(_otherName));
      final scope = ShoppingArea(
        mode: 'nearby',
        latitudeE6: 7000000,
        longitudeE6: 125000000,
        accuracyM: 1500,
        capturedAtUtc: DateTime.now().toUtc(),
      );
      await repository.saveShoppingArea(scope.toRow());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PricesPage)),
      );
      await container.read(appProvider.notifier).refresh();
      await helpers.settle(tester);
      // Turn off this screen's local override before checking nearby filtering.
      final switchTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Show all areas'),
      );
      if (switchTile.value) await _allAreas(tester);
      await helpers.reveal(
        tester,
        find.textContaining('1 stores without GPS tags'),
      );
      await helpers.reveal(tester, find.text(_localName));
      expect(find.text(_otherName), findsNothing);
    },
  );

  testWidgets(
    'offer chooser uses selected area and All areas choice preserves saved scope and frozen estimate',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await _seedScoped(repository);
      final before = await repository.load();
      await helpers.mount(
        tester,
        repository,
        form: const ItemForm(
          listId: helpers.listId,
          productId: helpers.productId,
        ),
        viewport: const Size(420, 1200),
      );
      await helpers.enter(tester, 'Quantity you need', '750');
      final mode = find.widgetWithText(
        DropdownButtonFormField<String>,
        'How to estimate',
      );
      await _tapVisible(tester, mode);
      await tester.tap(find.text('Use a recorded price').last);
      await helpers.settle(tester);
      await _tapVisible(tester, find.text('Choose recorded price'));
      expect(find.textContaining(_localName), findsOneWidget);
      expect(find.textContaining(_otherName), findsNothing);
      final all = find.widgetWithText(SwitchListTile, 'Show all areas');
      await tester.tap(all);
      await helpers.settle(tester);
      await tester.scrollUntilVisible(
        find.textContaining(_otherName),
        100,
        scrollable: find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.textContaining(_otherName));
      await helpers.settle(tester);
      await tester.tap(find.text('Save'));
      await helpers.settle(tester);
      final after = await repository.load();
      expect(after.settings, before.settings);
      final item = after.items.singleWhere(
        (row) => row['id'] != helpers.itemId,
      );
      expect(
        (item['estimate_basis_snapshot'] as Map)['store_name'],
        _otherName,
      );
      expect(
        item['estimate_total_centavos'],
        7000,
        reason: '750 g requires two whole 500 g packs at PHP 35.',
      );
      expect(after.purchases, isEmpty);
    },
  );

  testWidgets(
    'a record opened through Show all areas keeps that scope in product detail',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await _seedScoped(repository, emptyArea: true);
      final before = (await repository.load()).settings;
      await helpers.mount(tester, repository, viewport: const Size(420, 1200));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Prices'),
        ),
      );
      await helpers.settle(tester);
      await _allAreas(tester);
      await _tapVisible(tester, find.text(_otherName));
      expect(find.byType(ProductDetail), findsOneWidget);
      final all = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Show all areas'),
      );
      expect(all.value, isTrue);
      await helpers.reveal(tester, find.text(_otherName).first);
      expect(find.text(_otherName), findsWidgets);
      expect((await repository.load()).settings, before);
    },
  );

  testWidgets(
    'location manual form and store tag controls remain usable at 200% with a keyboard',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await helpers.seed(repository);
      await helpers.mount(
        tester,
        repository,
        form: const ShoppingAreaPage(),
        scale: 2,
      );
      await _selectArea(tester, 'manual');
      await helpers.enter(tester, 'City or municipality', 'Readable city');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      final save = find.text('Save shopping area');
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(520));
      expect(tester.getRect(save).top, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.tap(save);
      await helpers.settle(tester);
      tester.view.resetViewInsets();
      final service = _ControlledLocation(() async => _fix());
      await helpers.mount(
        tester,
        repository,
        scale: 2,
        form: CatalogForm(product: false, locationService: service),
      );
      await helpers.enter(tester, 'Store or stall name', 'Accessible store');
      await _tapVisible(
        tester,
        find.text('Tag this store with my current location'),
      );
      await helpers.reveal(tester, find.text('Remove location tag'));
      final semantics = tester.ensureSemantics();
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
