import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Row;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/app/app.dart';
import 'package:presyo_mlang/app/controller.dart';
import 'package:presyo_mlang/app/strings.dart';
import 'package:presyo_mlang/app/theme.dart';
import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/features/common.dart';
import 'package:presyo_mlang/features/prices.dart';
import 'package:presyo_mlang/features/lists.dart';
import 'package:presyo_mlang/features/spending.dart';

const productId = '10000000-0000-4000-8000-000000000001';
const storeId = '10000000-0000-4000-8000-000000000002';
const listId = '10000000-0000-4000-8000-000000000003';
const itemId = '10000000-0000-4000-8000-000000000004';

/// Uses the real repository and SQLite, with no file/path-provider side effects.
class MemoryController extends AppController {
  MemoryController(this.testRepository, {bool demo = false}) {
    isDemo = demo;
  }

  final AppRepository testRepository;

  @override
  AppRepository get repository => testRepository;

  @override
  Future<AppData> build() => repository.load();
}

class FailOnceRepository extends AppRepository {
  FailOnceRepository(super.db);
  bool failNextPrice = true;

  @override
  Future<void> savePrice(Row input) async {
    if (failNextPrice) {
      failNextPrice = false;
      throw StateError('Injected test write failure.');
    }
    await super.savePrice(input);
  }
}

class FailOnceBudgetRepository extends AppRepository {
  FailOnceBudgetRepository(super.db);
  int budgetSaveCalls = 0;
  final firstWrite = Completer<void>();

  @override
  Future<void> setMonthlyBudget(String month, int? centavos) async {
    budgetSaveCalls++;
    if (budgetSaveCalls == 1) {
      await firstWrite.future;
    }
    await super.setMonthlyBudget(month, centavos);
  }
}

Future<void> seed(AppRepository repository, {bool shoppingList = false}) async {
  await repository.setSetting('onboarded', true);
  await repository.saveProduct({
    'id': productId,
    'name': 'Test tomatoes',
    'category': 'Vegetables',
    'quantity_kind': 'mass',
  });
  await repository.saveStore({'id': storeId, 'name': 'Test stall'});
  if (shoppingList) {
    await repository.saveList({
      'id': listId,
      'title': 'Test shopping list',
      'budget_centavos': 50000,
    });
    await repository.saveItem({
      'id': itemId,
      'list_id': listId,
      'product_id': productId,
      'requested_quantity_base': 750,
    });
  }
}

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 50),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 10),
);

Future<void> mount(
  WidgetTester tester,
  AppRepository repository, {
  Widget? form,
  bool demo = false,
  double scale = 1,
  Size viewport = const Size(320, 800),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture'),
      child: ProviderScope(
        overrides: [
          appProvider.overrideWith(
            () => MemoryController(repository, demo: demo),
          ),
        ],
        child: form == null
            ? const PresyoApp()
            : MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: appTheme(),
                home: Consumer(
                  builder: (context, ref, child) {
                    return ref
                        .watch(appProvider)
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stack) => Text(error.toString()),
                          data: (_) => Scaffold(
                            body: Center(
                              child: FilledButton(
                                onPressed: () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(builder: (_) => form),
                                ),
                                child: const Text('Open test form'),
                              ),
                            ),
                          ),
                        );
                  },
                ),
              ),
      ),
    ),
  );
  await settle(tester);
  if (form != null) {
    await tester.tap(find.text('Open test form'));
    await settle(tester);
  }
}

Finder input(String label) => find.widgetWithText(TextFormField, label);

/// Build lazy list children from the current route, then bring the target well
/// inside the viewport. Returning to the top also makes reverse navigation
/// deterministic after the keyboard has scrolled a form down.
Future<void> reveal(WidgetTester tester, Finder target) async {
  final lists = find.byType(ListView);
  if (lists.evaluate().isEmpty) {
    await tester.ensureVisible(target);
    return;
  }
  final scrollable = find
      .descendant(of: lists.last, matching: find.byType(Scrollable))
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
  await Scrollable.ensureVisible(tester.element(target), alignment: .35);
  await settle(tester);
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  final field = input(label);
  await reveal(tester, field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> expectDraft(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = input(label);
  await reveal(tester, field);
  expect(tester.widget<TextFormField>(field).controller!.text, value);
  expect(find.text(value), findsOneWidget);
}

Future<void> selectStore(WidgetTester tester) async {
  final store = find.widgetWithText(
    DropdownButtonFormField<String>,
    'Store or stall',
  );
  await reveal(tester, store);
  await tester.tap(store);
  await settle(tester);
  await tester.tap(find.text('Test stall').last);
  await settle(tester);
}

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final rendered = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final output = File('docs/screenshots/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    rendered.dispose();
  });
}

/// Readable local QA glyphs only. No system font is copied into the app or repo.
Future<void> loadReadableQaFont(WidgetTester tester) async {
  await tester.runAsync(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final candidates = [
      File('C:/Windows/Fonts/segoeui.ttf'),
      if (flutterRoot != null)
        File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ),
    ];
    File? selected;
    for (final candidate in candidates) {
      if (await candidate.exists()) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) {
      throw TestFailure(
        'A readable local font is required for QA screenshots.',
      );
    }
    final bytes = await selected.readAsBytes();
    for (final family in {
      'Roboto',
      appTheme().textTheme.bodyMedium?.fontFamily ?? 'Roboto',
    }) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final icons = File(
      '${flutterRoot ?? 'G:/DevTools/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (!await icons.exists()) {
      throw TestFailure('The bundled Material Icons font is required for QA.');
    }
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
    await iconLoader.load();
  });
}

void main() {
  testWidgets(
    'first run offers empty notebook and fictional demo without invented statistics',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await mount(tester, repository, scale: 2);
      await tester.scrollUntilVisible(
        find.text('Start empty'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Start empty'), findsOneWidget);
      expect(find.text('Try fictional demo'), findsOneWidget);
      expect((await repository.load()).prices, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('four real tabs remain usable at 320px and 200% text', (
    tester,
  ) async {
    final repository = AppRepository(AppDatabase.memory());
    addTearDown(repository.close);
    await seed(repository);
    await mount(tester, repository, scale: 2);
    for (final label in ['Lists', 'Prices', 'Spending', 'Home']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await settle(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: '$label must not overflow.',
      );
    }
    final semantics = tester.ensureSemantics();
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets(
    'confirmed local reset allows onboarding again in the same process',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await mount(tester, repository);
      await reveal(tester, find.text('Start empty'));
      await tester.tap(find.text('Start empty'));
      await settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.byTooltip('Settings, backup, and privacy'));
      await settle(tester);
      await reveal(tester, find.text('Delete all real local records'));
      await tester.tap(find.text('Delete all real local records'));
      await settle(tester);
      await tester.tap(find.text('Delete local records'));
      await settle(tester);
      await reveal(tester, find.text('Start empty'));
      final start = find.ancestor(
        of: find.text('Start empty'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.tap(find.text('Start empty'));
      await settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect((await repository.load()).settings['onboarded'], isTrue);
    },
  );

  testWidgets('demo label persists on a pushed price form', (tester) async {
    final repository = AppRepository(AppDatabase.memory(), demo: true);
    addTearDown(repository.close);
    await repository.seedDemo();
    await mount(tester, repository, demo: true, form: const PriceForm());
    expect(find.text(AppStrings.demo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'canceling an actual purchase changes neither ledger nor Needed state',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository, shoppingList: true);
      final item = (await repository.load()).items.single;
      await mount(tester, repository, form: PurchaseForm(item: item));
      await enter(tester, 'Actual total paid (PHP)', '165');
      await tester.pageBack();
      await settle(tester);
      final unchanged = await repository.load();
      expect(unchanged.purchases, isEmpty);
      expect(unchanged.items.single['status'], 'needed');
      expect(find.text('Open test form'), findsOneWidget);
    },
  );

  testWidgets(
    'actual purchase Save is explicit and duplicate taps record one expense',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository, shoppingList: true);
      final item = (await repository.load()).items.single;
      await mount(tester, repository, form: PurchaseForm(item: item));
      await enter(tester, 'Actual total paid (PHP)', '165');
      expect((await repository.load()).purchases, isEmpty);
      final save = find.text('Save actual purchase');
      await tester.tap(save);
      await tester.tap(save);
      await settle(tester);
      final saved = await repository.load();
      expect(saved.purchases, hasLength(1));
      expect(saved.purchases.single['actual_total_centavos'], 16500);
      expect(saved.items.single['status'], 'bought');
      expect(listTotals(saved, listId).actualSpent, 16500);
      expect(find.text('Open test form'), findsOneWidget);
    },
  );

  testWidgets(
    'failed price save keeps form values and allows a successful retry',
    (tester) async {
      final repository = FailOnceRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository);
      await mount(
        tester,
        repository,
        form: const PriceForm(productId: productId),
      );
      await selectStore(tester);
      await enter(tester, 'Total quoted price (PHP)', '45.50');
      await enter(tester, 'Quantity covered by this price', '500');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.byType(PriceForm), findsOneWidget);
      await expectDraft(tester, 'Total quoted price (PHP)', '45.50');
      await expectDraft(tester, 'Quantity covered by this price', '500');
      expect((await repository.load()).prices, isEmpty);
      await tester.pump(const Duration(seconds: 8));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect((await repository.load()).prices.single['quoted_centavos'], 4550);
      expect(find.text('Open test form'), findsOneWidget);
    },
  );

  testWidgets(
    'inline store creation returns to the price draft without losing inputs',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository);
      await mount(
        tester,
        repository,
        form: const PriceForm(productId: productId),
      );
      await enter(tester, 'Total quoted price (PHP)', '45.50');
      await enter(tester, 'Quantity covered by this price', '500');
      await reveal(tester, find.text('Add store here'));
      await tester.tap(find.text('Add store here'));
      await settle(tester);
      await enter(tester, 'Store or stall name', 'Another test stall');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.byType(PriceForm), findsOneWidget);
      await expectDraft(tester, 'Total quoted price (PHP)', '45.50');
      await expectDraft(tester, 'Quantity covered by this price', '500');
      expect((await repository.load()).prices, isEmpty);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final saved = await repository.load();
      expect(saved.prices.single['quoted_centavos'], 4550);
      expect(
        saved.store(saved.prices.single['store_id'] as String)!['name'],
        'Another test stall',
      );
    },
  );

  testWidgets(
    'inline product with the same measurement kind preserves kg and decimal quantity',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository);
      await mount(
        tester,
        repository,
        form: const PriceForm(productId: productId),
      );
      await selectStore(tester);
      await enter(tester, 'Total quoted price (PHP)', '45.50');
      final unit = find.widgetWithText(DropdownButtonFormField<String>, 'Unit');
      await reveal(tester, unit);
      await tester.tap(unit);
      await settle(tester);
      await tester.tap(find.text('kg').last);
      await settle(tester);
      await enter(tester, 'Quantity covered by this price', '0.5');
      await reveal(tester, find.text('Add product here'));
      await tester.tap(find.text('Add product here'));
      await settle(tester);
      await enter(tester, 'Product name', 'Another test product');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.byType(PriceForm), findsOneWidget);
      await expectDraft(tester, 'Total quoted price (PHP)', '45.50');
      await expectDraft(tester, 'Quantity covered by this price', '0.5');
      await tester.tap(find.text('Save'));
      await settle(tester);
      final saved = await repository.load();
      expect(saved.prices.single['offered_quantity_base'], 500);
      expect(
        saved.product(saved.prices.single['product_id'] as String)['name'],
        'Another test product',
      );
    },
  );

  testWidgets('price form retains visible Save with keyboard and 200% text', (
    tester,
  ) async {
    final repository = AppRepository(AppDatabase.memory());
    addTearDown(repository.close);
    await seed(repository);
    await mount(
      tester,
      repository,
      form: const PriceForm(productId: productId),
      scale: 2,
    );
    await reveal(tester, input('Total quoted price (PHP)'));
    await tester.tap(input('Total quoted price (PHP)'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    final saveRect = tester.getRect(
      find.ancestor(
        of: find.text('Save'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(saveRect.top, greaterThanOrEqualTo(0));
    expect(saveRect.bottom, lessThanOrEqualTo(500));
    expect(saveRect.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'price filters recover after catalog edits and replacement restore',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository);
      await repository.savePrice({
        'product_id': productId,
        'store_id': storeId,
        'quoted_centavos': 4500,
        'offered_quantity_base': 500,
        'observed_on': dateText(manilaToday()),
      });
      await mount(tester, repository);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Prices'),
        ),
      );
      await settle(tester);
      final category = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Category',
      );
      final store = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Store',
      );
      await reveal(tester, category);
      await tester.tap(category);
      await settle(tester);
      await tester.tap(find.text('Vegetables').last);
      await settle(tester);
      await reveal(tester, store);
      await tester.tap(store);
      await settle(tester);
      await tester.tap(find.text('Test stall').last);
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PricesPage)),
      );
      await repository.saveProduct({'id': productId, 'category': 'Fruit'});
      await container.read(appProvider.notifier).refresh();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('All categories'), findsOneWidget);
      expect(find.byType(PriceCard), findsOneWidget);

      final replacement = AppRepository(AppDatabase.memory());
      addTearDown(replacement.close);
      const replacementStore = '10000000-0000-4000-8000-000000000005';
      await replacement.setSetting('onboarded', true);
      await replacement.saveProduct({
        'id': productId,
        'name': 'Restored test tomatoes',
        'category': 'Other',
        'quantity_kind': 'mass',
      });
      await replacement.saveStore({
        'id': replacementStore,
        'name': 'Restored test stall',
      });
      await replacement.savePrice({
        'product_id': productId,
        'store_id': replacementStore,
        'quoted_centavos': 5500,
        'offered_quantity_base': 500,
        'observed_on': dateText(manilaToday()),
      });
      await repository.restore(await replacement.load());
      await container.read(appProvider.notifier).refresh();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('All stores'), findsOneWidget);
      expect(find.text('All categories'), findsOneWidget);
      expect(find.byType(PriceCard), findsOneWidget);
      expect(find.text('Restored test tomatoes'), findsOneWidget);
    },
  );

  testWidgets(
    'failed monthly budget save preserves the dialog draft for retry',
    (tester) async {
      final repository = FailOnceBudgetRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository);
      await mount(tester, repository);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Spending'),
        ),
      );
      await settle(tester);
      await reveal(tester, find.text('Set monthly budget'));
      await tester.tap(find.text('Set monthly budget'));
      await settle(tester);
      await enter(tester, 'Monthly budget (PHP)', '321.50');
      await tester.tap(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(repository.budgetSaveCalls, 1);
      expect(find.text('Saving…'), findsOneWidget);
      repository.firstWrite.completeError(
        StateError('Injected test budget write failure.'),
      );
      await settle(tester);
      expect(repository.budgetSaveCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('321.50'), findsOneWidget);
      expect((await repository.load()).monthlyBudgets, isEmpty);
      await tester.pump(const Duration(seconds: 8));
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(repository.budgetSaveCalls, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        (await repository.load()).monthlyBudgets[dateText(
          manilaToday(),
        ).substring(0, 7)],
        32150,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'list price chooser requires explicit opt-in before selecting older offers',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository, shoppingList: true);
      final oldDate = dateText(manilaToday().subtract(const Duration(days: 8)));
      await repository.savePrice({
        'product_id': productId,
        'store_id': storeId,
        'quoted_centavos': 4500,
        'offered_quantity_base': 500,
        'observed_on': oldDate,
      });
      await mount(
        tester,
        repository,
        form: const ItemForm(listId: listId, productId: productId),
      );
      await enter(tester, 'Quantity you need', '750');
      final mode = find.widgetWithText(
        DropdownButtonFormField<String>,
        'How to estimate',
      );
      await reveal(tester, mode);
      await tester.tap(mode);
      await settle(tester);
      await tester.tap(find.text('Use a recorded price').last);
      await settle(tester);
      await reveal(tester, find.text('Choose recorded price'));
      await tester.tap(find.text('Choose recorded price'));
      await settle(tester);
      expect(find.text('No recent comparable records'), findsOneWidget);
      expect(find.text('₱45.00 / 500 g'), findsNothing);
      await tester.tap(find.text('Show older records'));
      await settle(tester);
      expect(find.text('₱45.00 / 500 g'), findsOneWidget);
      expect(find.textContaining('$oldDate · Older record'), findsOneWidget);
      await tester.tap(find.text('₱45.00 / 500 g'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final added = (await repository.load()).items.last;
      expect(added['estimate_total_centavos'], 6750);
      expect(added['estimate_basis_snapshot']['observed_on'], oldDate);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date picker supports the earliest accepted backup date', (
    tester,
  ) async {
    final repository = AppRepository(AppDatabase.memory());
    addTearDown(repository.close);
    await mount(
      tester,
      repository,
      form: AppPage(
        title: 'Historical date test',
        child: DateField(value: '0001-01-01', onChanged: (_) {}),
      ),
    );
    await tester.tap(find.text('Date observed: 0001-01-01'));
    await settle(tester);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Date observed: 0001-01-01'), findsOneWidget);
  });

  testWidgets(
    'rendered fictional workflows provide phone-sized visual QA artifacts',
    (tester) async {
      await loadReadableQaFont(tester);
      final repository = AppRepository(AppDatabase.memory(), demo: true);
      addTearDown(repository.close);
      await repository.seedDemo();
      var data = await repository.load();
      final product = data.products.single['id'] as String;
      final list = data.lists.single['id'] as String;
      await repository.savePurchase({
        'list_item_id': data.items.single['id'],
        'product_id': product,
        'actual_quantity_base': 1000,
        'actual_total_centavos': 16500,
        'purchased_on': dateText(manilaToday()),
      });
      await repository.saveItem({
        'list_id': list,
        'product_id': product,
        'requested_quantity_base': 2000,
        'estimate_mode': 'manual',
        'estimate_total_centavos': 31000,
      });
      await repository.saveItem({
        'list_id': list,
        'product_id': product,
        'requested_quantity_base': 500,
      });
      data = await repository.load();
      expect(listTotals(data, list).projectedTotal, 47500);
      await mount(
        tester,
        repository,
        demo: true,
        viewport: const Size(390, 844),
      );
      await capture(tester, 'home_demo_390');
      for (final label in ['Prices', 'Spending']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, '${label.toLowerCase()}_demo_390');
      }
      await mount(
        tester,
        repository,
        demo: true,
        form: ListDetail(listId: list),
        viewport: const Size(390, 844),
      );
      await capture(tester, 'list_demo_390');
      expect(tester.takeException(), isNull);
      await mount(
        tester,
        repository,
        demo: true,
        viewport: const Size(320, 800),
        scale: 2,
      );
      await capture(tester, 'home_demo_320_text200');
      expect(tester.takeException(), isNull);
    },
  );

  test('primary text and actions meet the ordinary-text contrast target', () {
    final theme = appTheme();
    double contrast(Color a, Color b) {
      final first = a.computeLuminance();
      final second = b.computeLuminance();
      return first >= second
          ? (first + 0.05) / (second + 0.05)
          : (second + 0.05) / (first + 0.05);
    }

    expect(
      contrast(theme.colorScheme.primary, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(theme.colorScheme.onSurface, theme.scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
  });
}
