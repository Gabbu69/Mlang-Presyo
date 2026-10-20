import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/models.dart' show AppData;
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/features/common.dart';
import 'package:presyo_mlang/features/prices.dart';

import 'app_flow_test.dart' show mount, reveal, seed, settle, storeId;

String _id(String prefix, int index) =>
    '$prefix-0000-4000-8000-${index.toString().padLeft(12, '0')}';

List<PriceCard> _results(WidgetTester tester) => tester
    .widget<PagePadding>(
      find.descendant(
        of: find.byType(PricesPage),
        matching: find.byType(PagePadding),
      ),
    )
    .children
    .whereType<PriceCard>()
    .toList();

void main() {
  testWidgets(
    'search survives disposal of its unfocused lazy text field and can clear',
    (tester) async {
      final repository = AppRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository);
      final base = await repository.load();
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final date = dateText(manilaToday());
      await repository.restore(
        AppData(
          products: [
            for (var index = 0; index < 60; index++)
              {
                ...base.products.single,
                'id': _id('71000000', index),
                'name': index < 30
                    ? 'Retained search fixture $index'
                    : 'Other fictional fixture $index',
              },
          ],
          stores: base.stores,
          prices: [
            for (var index = 0; index < 60; index++)
              {
                'id': _id('72000000', index),
                'product_id': _id('71000000', index),
                'store_id': storeId,
                'quoted_centavos': 1000 + index,
                'offered_quantity_base': 500,
                'selling_mode': 'loose',
                'offer_type': 'regular',
                'source_type': 'observed',
                'observed_on': date,
                'notes': '',
                'created_at_utc': timestamp,
                'updated_at_utc': timestamp,
              },
          ],
          settings: base.settings,
        ),
      );
      await mount(tester, repository, viewport: const Size(390, 844));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Prices'),
        ),
      );
      await settle(tester);
      final search = find.byType(TextField);
      await reveal(tester, search);
      await tester.enterText(search, 'Retained search');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      expect(_results(tester), hasLength(30));
      final originalInput = tester.state<EditableTextState>(
        find.byType(EditableText),
      );

      final lastId = _results(tester).last.price['id'];
      final lastCard = find.byWidgetPredicate(
        (widget) => widget is PriceCard && widget.price['id'] == lastId,
      );
      await reveal(tester, lastCard);
      expect(
        originalInput.mounted,
        isFalse,
        reason:
            'This regression must recreate the unfocused field after scrolling.',
      );
      await reveal(tester, search);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Retained search',
      );
      expect(_results(tester), hasLength(30));

      await tester.enterText(search, '');
      await settle(tester);
      expect(_results(tester), hasLength(60));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
