import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/models.dart';

final today = DateTime.parse('2026-10-16T06:00:00Z');

Row quote({
  String id = 'quote-a',
  String product = 'product-a',
  String store = 'store-a',
  int amount = 4500,
  int quantity = 500,
  String mode = 'loose',
  String offer = 'regular',
  String date = '2026-10-16',
  String updated = '2026-10-16T06:00:00.000Z',
}) => {
  'id': id,
  'product_id': product,
  'store_id': store,
  'quoted_centavos': amount,
  'offered_quantity_base': quantity,
  'selling_mode': mode,
  'offer_type': offer,
  'source_type': 'observed',
  'observed_on': date,
  'updated_at_utc': updated,
};

AppData budgetFixture({bool missing = false, int? budget = 50000}) => AppData(
  products: [
    {'id': 'product-a', 'name': 'Fictional apples', 'category': 'Produce'},
  ],
  lists: [
    {'id': 'list-a', 'budget_centavos': budget, 'status': 'active'},
  ],
  items: [
    {
      'id': 'bought',
      'list_id': 'list-a',
      'status': 'bought',
      'estimate_total_centavos': 99999,
    },
    {
      'id': 'needed',
      'list_id': 'list-a',
      'status': 'needed',
      'estimate_total_centavos': 31000,
    },
    {
      'id': 'skipped',
      'list_id': 'list-a',
      'status': 'skipped',
      'estimate_total_centavos': 88888,
    },
    if (missing)
      {
        'id': 'unestimated',
        'list_id': 'list-a',
        'status': 'needed',
        'estimate_total_centavos': null,
      },
  ],
  purchases: [
    {
      'id': 'purchase-a',
      'list_item_id': 'bought',
      'actual_total_centavos': 16500,
      'purchased_on': '2026-10-01',
      'product_snapshot': {'name': 'Fictional apples', 'category': 'Produce'},
    },
  ],
);

void main() {
  group('T01–T04 exact money and canonical quantities', () {
    test(
      'T01 decimal strings become exact centavos and format with two decimals',
      () {
        expect(parseMoney('45.50'), 4550);
        expect(parseMoney('45.5'), 4550);
        expect(parseMoney(' 00045.50 '), 4550);
        expect(money(4550), '₱45.50');
        expect(money(123456789), '₱1,234,567.89');
        expect(money(-123456), '-₱1,234.56');
        expect(moneyInput(123456), '1234.56');
        expect(
          List.filled(10, parseMoney('0.10')).reduce((a, b) => a + b),
          100,
        );
      },
    );

    test(
      'T02 invalid, negative, exponent, and oversized money is rejected',
      () {
        for (final input in [
          '',
          '-1',
          '+1',
          '1.234',
          '1e3',
          'NaN',
          'Infinity',
          '.5',
          '1,000',
          '1.',
        ]) {
          expect(
            () => parseMoney(input),
            throwsA(isA<ValidationException>()),
            reason: input,
          );
        }
        expect(
          () => parseMoney('1000000.01'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => parseMoney('0', positive: true),
          throwsA(isA<ValidationException>()),
        );
        expect(parseMoney('0'), 0);
        expect(parseMoney('1000000'), maxMoneyCentavos);
        expect(
          parseMoney('10000000', max: maxBudgetCentavos),
          maxBudgetCentavos,
        );
        expect(
          () => parseMoney('10000000.01', max: maxBudgetCentavos),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('T03 measured quantity conversion never uses binary decimals', () {
      expect(parseQuantity('0.5', 'kg', 'mass'), 500);
      expect(parseQuantity('0.001', 'kg', 'mass'), 1);
      expect(parseQuantity('1.25', 'L', 'volume'), 1250);
      expect(parseQuantity('12', 'pieces', 'count'), 12);
      expect(parseQuantity('1000', 'kg', 'mass'), maxCanonicalQuantity);
      expect(quantityLabel(500, 'mass'), '500 g');
      expect(quantityLabel(1250, 'volume'), '1250 mL');
      expect(quantityLabel(12, 'count'), '12 pcs');
    });

    test(
      'T02/T03 unsupported, fractional base, zero, and oversized quantities fail',
      () {
        for (final args in [
          ['0', 'g', 'mass'],
          ['-1', 'g', 'mass'],
          ['0.0001', 'kg', 'mass'],
          ['1.1', 'g', 'mass'],
          ['1.1', 'mL', 'volume'],
          ['1.5', 'pieces', 'count'],
          ['1', 'tray', 'count'],
          ['1', 'cup', 'volume'],
          ['1', 'kg', 'volume'],
          ['1', 'L', 'mass'],
          ['1e3', 'g', 'mass'],
          ['1000001', 'g', 'mass'],
          ['1000.001', 'kg', 'mass'],
        ]) {
          expect(
            () => parseQuantity(args[0], args[1], args[2]),
            throwsA(isA<ValidationException>()),
            reason: args.join(' '),
          );
        }
      },
    );

    test('T04 round only the final positive rational boundary', () {
      expect(
        estimatePrice(quote(amount: 100, quantity: 3), 3).totalCentavos,
        100,
      );
      expect(estimatePrice(quote(amount: 1, quantity: 2), 1).totalCentavos, 1);
      expect(roundHalfUp(1, 2), 1);
      expect(roundHalfUp(1, 3), 0);
      expect(roundHalfUp(5, 2), 3);
      expect(() => roundHalfUp(1, 0), throwsA(isA<ValidationException>()));
      expect(() => roundHalfUp(-1, 2), throwsA(isA<ValidationException>()));
      // 100,000,000 × 1,000,000 remains exact before division.
      expect(
        estimatePrice(
          quote(amount: 100000000, quantity: 3),
          1000000,
        ).totalCentavos,
        33333333333333,
      );
    });
  });

  group('T05–T12 trustworthy comparison and Manila dates', () {
    test('T05 exact normalized values and ordering', () {
      final a = quote();
      final b = quote(
        id: 'quote-b',
        store: 'store-b',
        amount: 8500,
        quantity: 1000,
      );
      expect(normalizedCentavos(a, 'mass'), 9000);
      expect(normalizedCentavos(b, 'mass'), 8500);
      expect(
        comparablePrices(
          [a, b],
          'product-a',
          now: today,
        ).map((row) => row['id']),
        ['quote-b', 'quote-a'],
      );
      expect(
        normalizedCentavos(quote(amount: 9900, quantity: 12), 'count'),
        825,
      );
      expect(
        normalizedCentavos(quote(amount: 4500, quantity: 500), 'volume'),
        9000,
      );
    });

    test('T06 loose and whole-package payable totals remain distinct', () {
      final sealed = estimatePrice(quote(mode: 'packaged'), 750);
      expect(sealed.packages, 2);
      expect(sealed.totalCentavos, 9000);
      expect(sealed.extraQuantity, 250);
      final loose = estimatePrice(quote(), 750);
      expect(loose.totalCentavos, 6750);
      expect(loose.packages, isNull);
      expect(loose.extraQuantity, 0);
      final kilogramPack = estimatePrice(
        quote(amount: 8500, quantity: 1000, mode: 'packaged'),
        500,
      );
      expect(kilogramPack.totalCentavos, 8500);
      expect(kilogramPack.packages, 1);
      expect(kilogramPack.extraQuantity, 500);
    });

    test('T07 explicit variant identity excludes other product IDs', () {
      final result = comparablePrices(
        [
          quote(),
          quote(id: 'other-brand', product: 'another-brand', amount: 1),
          quote(id: 'other-grade', product: 'another-grade', amount: 1),
          quote(id: 'other-kind', product: 'another-kind', amount: 1),
        ],
        'product-a',
        now: today,
      );
      expect(result.single['id'], 'quote-a');
      expect(
        () => normalizedCentavos(quote(quantity: 0), 'count'),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'T08 newest eligible group observation replaces obsolete cheaper quote',
      () {
        final history = [
          quote(id: 'old', amount: 8000, quantity: 1000, date: '2026-10-13'),
          quote(id: 'new', amount: 9000, quantity: 1000, date: '2026-10-15'),
          quote(id: 'different-size', amount: 4300, quantity: 500),
          quote(
            id: 'different-mode',
            amount: 4400,
            quantity: 500,
            mode: 'packaged',
          ),
        ];
        expect(
          comparablePrices(
            history,
            'product-a',
            now: today,
          ).map((row) => row['id']),
          ['different-size', 'different-mode', 'new'],
        );
        expect(history.length, 4, reason: 'Selection must not erase history.');
      },
    );

    test('T08 deterministic same-day timestamp and ID tie-breaking', () {
      final result = comparablePrices(
        [
          quote(id: 'z', updated: '2026-10-16T06:00:00.000Z'),
          quote(id: 'a', updated: '2026-10-16T06:00:00.000001Z'),
        ],
        'product-a',
        now: today,
      );
      expect(
        result.single['id'],
        'a',
        reason:
            'Compare timestamps as instants, including fractional precision.',
      );
      final tied = comparablePrices(
        [quote(id: 'a'), quote(id: 'z')],
        'product-a',
        now: today,
      );
      expect(tied.single['id'], 'z');
    });

    test('T09 age seven is included, age eight opt-in preserves label', () {
      final prices = [
        quote(id: 'seven', date: '2026-10-09'),
        quote(id: 'eight', store: 'store-b', date: '2026-10-08'),
      ];
      expect(ageDays('2026-10-09', now: today), 7);
      expect(ageLabel('2026-10-09', now: today), 'Recent record');
      expect(ageLabel('2026-10-08', now: today), 'Older record');
      expect(
        comparablePrices(prices, 'product-a', now: today).single['id'],
        'seven',
      );
      expect(
        comparablePrices(prices, 'product-a', older: true, now: today).length,
        2,
      );
      expect(ageLabel('2026-10-08', now: today), 'Older record');
      expect(ageLabel('2026-09-16', now: today), 'Older record');
      expect(ageLabel('2026-09-15', now: today), 'Old record');
    });

    test('T10 stale-only candidate set is empty until explicit opt-in', () {
      final stale = [quote(date: '2026-09-01')];
      expect(comparablePrices(stale, 'product-a', now: today), isEmpty);
      expect(
        comparablePrices(stale, 'product-a', older: true, now: today).length,
        1,
      );
      expect(
        () => validateDate('2026-10-17', now: today),
        throwsA(isA<ValidationException>()),
      );
      for (final date in [
        '2026-02-29',
        '2026-13-01',
        '2026-00-01',
        '0000-01-01',
        '2026-10-1',
      ]) {
        expect(
          () => validateDate(date, now: today),
          throwsA(isA<ValidationException>()),
          reason: date,
        );
      }
      expect(() => validateDate('2024-02-29', now: today), returnsNormally);
    });

    test('T11 Manila midnight is independent of device timezone', () {
      expect(
        dateText(manilaToday(DateTime.parse('2026-10-16T15:30:00Z'))),
        '2026-10-16',
      );
      expect(
        dateText(manilaToday(DateTime.parse('2026-10-16T16:30:00Z'))),
        '2026-10-17',
      );
      expect(
        dateText(manilaToday(DateTime.parse('2026-10-16T09:30:00-07:00'))),
        '2026-10-17',
      );
      expect(
        ageLabel('2026-10-16', now: DateTime.parse('2026-10-16T16:30:00Z')),
        'Recent record',
      );
      final editedOld = quote(
        date: '2026-09-01',
        updated: '2026-10-16T06:00:00Z',
      );
      expect(
        ageLabel(editedOld['observed_on'] as String, now: today),
        'Old record',
      );
    });

    test(
      'T12 promotions/conditional offers excluded and fraction ranking stays exact',
      () {
        // At a per-kg display both round to 1 centavo; exact 0.999... beats 1.
        final a = quote(id: 'a', store: 'a', amount: 1, quantity: 1000);
        final z = quote(id: 'z', store: 'z', amount: 1, quantity: 1001);
        expect(normalizedCentavos(a, 'mass'), 1);
        expect(normalizedCentavos(z, 'mass'), 1);
        expect(
          comparablePrices(
            [
              a,
              z,
              quote(
                id: 'promo',
                store: 'promo',
                amount: 1,
                offer: 'promotional',
              ),
              quote(
                id: 'conditional',
                store: 'conditional',
                amount: 1,
                offer: 'conditional',
              ),
            ],
            'product-a',
            now: today,
          ).map((row) => row['id']),
          ['z', 'a'],
        );
      },
    );
  });

  group('T13/T14/T18 ledger-based totals and frozen snapshots', () {
    test('T13 complete budget projection separates all amounts', () {
      final totals = listTotals(budgetFixture(), 'list-a');
      expect(totals.actualSpent, 16500);
      expect(totals.remainingEstimate, 31000);
      expect(totals.projectedTotal, 47500);
      expect(totals.budgetLeft, 33500);
      expect(totals.projectedBalance, 2500);
      expect(totals.missingEstimates, 0);
    });

    test('T14 incomplete estimates suppress a complete projected balance', () {
      final totals = listTotals(budgetFixture(missing: true), 'list-a');
      expect(totals.projectedTotal, 47500);
      expect(totals.missingEstimates, 1);
      expect(totals.projectedBalance, isNull);
      expect(totals.budgetLeft, 33500);
      final noBudget = listTotals(budgetFixture(budget: null), 'list-a');
      expect(noBudget.budgetLeft, isNull);
      expect(noBudget.projectedBalance, isNull);
    });

    test(
      'T16 explicit zero budget produces negative balance without division',
      () {
        final totals = listTotals(budgetFixture(budget: 0), 'list-a');
        expect(totals.budgetLeft, -16500);
        expect(totals.projectedBalance, -47500);
      },
    );

    test(
      'only linked ledger entries count toward a list; observations never count',
      () {
        final fixture = budgetFixture();
        final data = AppData(
          lists: fixture.lists,
          items: fixture.items,
          prices: [quote(amount: 99999999)],
          purchases: [
            ...fixture.purchases,
            {
              'id': 'standalone',
              'list_item_id': null,
              'actual_total_centavos': 5000,
              'purchased_on': '2026-10-02',
              'product_snapshot': {'category': 'Other'},
            },
            {
              'id': 'another-list',
              'list_item_id': 'another-list-item',
              'actual_total_centavos': 6000,
              'purchased_on': '2026-10-03',
              'product_snapshot': {'category': 'Other'},
            },
          ],
        );
        expect(listTotals(data, 'list-a').actualSpent, 16500);
        expect(monthlySpent(data, '2026-10'), 27500);
      },
    );

    test(
      'checked aggregate arithmetic rejects overflow instead of wrapping',
      () {
        final data = AppData(
          purchases: [
            {
              'actual_total_centavos': 9223372036854775807,
              'purchased_on': '2026-10-01',
            },
            {'actual_total_centavos': 1, 'purchased_on': '2026-10-01'},
          ],
        );
        expect(
          () => monthlySpent(data, '2026-10'),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'T18 monthly grouping uses purchase dates and historical category',
      () {
        final data = AppData(
          products: [
            {'id': 'a', 'name': 'Renamed product', 'category': 'New category'},
          ],
          lists: [
            {
              'id': 'list',
              'status': 'archived',
              'created_at_utc': '2026-09-01T00:00:00Z',
            },
          ],
          purchases: [
            {
              'id': 'sep',
              'list_item_id': 'same-list-item-a',
              'actual_total_centavos': 12000,
              'purchased_on': '2026-09-30',
              'product_snapshot': {'category': 'Original category'},
            },
            {
              'id': 'oct',
              'list_item_id': 'same-list-item-b',
              'actual_total_centavos': 16500,
              'purchased_on': '2026-10-01',
              'created_at_utc': '2026-09-30T16:01:00Z',
              'product_snapshot': {'category': 'Original category'},
            },
            {
              'id': 'standalone',
              'list_item_id': null,
              'actual_total_centavos': 0,
              'purchased_on': '2026-10-02',
              'product_snapshot': {'category': 'Other'},
            },
          ],
        );
        expect(monthlySpent(data, '2026-09'), 12000);
        expect(monthlySpent(data, '2026-10'), 16500);
        expect(categoryTotals(data, '2026-10'), {
          'Original category': 16500,
          'Other': 0,
        });
        expect(
          () => monthlySpent(data, '2026-13'),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('T17/T19 quote snapshots preserve the frozen calculation basis', () {
      final original = quote();
      final product = {
        'id': 'product-a',
        'name': 'Fictional apples',
        'category': 'Produce',
        'quantity_kind': 'mass',
      };
      final store = {'id': 'store-a', 'name': 'Demo Stall A'};
      final snapshot = priceSnapshot(original, product, store);
      original['quoted_centavos'] = 9900;
      product['name'] = 'Renamed';
      store['name'] = 'Renamed store';
      expect(snapshot['format_version'], 1);
      expect(snapshot['product_name'], 'Fictional apples');
      expect(snapshot['store_name'], 'Demo Stall A');
      expect(estimatePrice(snapshot, 750).totalCentavos, 6750);
      expect(estimatePrice(snapshot, 1000).totalCentavos, 9000);
    });

    test('T20 archived lists retain their purchase totals', () {
      final fixture = budgetFixture();
      final archived = AppData(
        lists: [
          {...fixture.lists.single, 'status': 'archived'},
        ],
        items: fixture.items,
        purchases: fixture.purchases,
      );
      expect(listTotals(archived, 'list-a').actualSpent, 16500);
      expect(monthlySpent(archived, '2026-10'), 16500);
    });
  });

  group('immutable read model', () {
    test('constructor detaches and deeply freezes nested snapshots', () {
      final source = <String, dynamic>{
        'id': 'p',
        'product_snapshot': {'category': 'Original'},
      };
      final data = AppData(purchases: [source]);
      (source['product_snapshot'] as Map)['category'] = 'Changed';
      expect(
        (data.purchases.single['product_snapshot'] as Map)['category'],
        'Original',
      );
      expect(() => data.purchases.add({}), throwsUnsupportedError);
      expect(() => data.purchases.single['id'] = 'x', throwsUnsupportedError);
      expect(
        () => (data.purchases.single['product_snapshot'] as Map)['category'] =
            'x',
        throwsUnsupportedError,
      );
    });

    test(
      'missing references raise readable validation errors and optional store may be null',
      () {
        final data = AppData.empty();
        expect(data.store(null), isNull);
        expect(data.purchaseFor('not-there'), isNull);
        expect(
          () => data.product('not-there'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => data.store('not-there'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => listTotals(data, 'not-there'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          const ValidationException('Readable message').toString(),
          'Readable message',
        );
      },
    );
  });
}
