import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../core/domain.dart';
import '../core/models.dart';
import 'database.dart';
import 'validation.dart';

class AppRepository {
  AppRepository(
    this.db, {
    bool demo = false,
    DateTime Function()? clock,
    this.writeCheckpoint,
  }) : isDemo = demo,
       _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final bool isDemo;
  final DateTime Function() _clock;

  /// Used by fault-injection tests. Never records private data in logs.
  final void Function(String stage)? writeCheckpoint;
  static const _uuid = Uuid();

  Future<void> close() => db.close();

  Future<AppData> load() => db.transaction(_read);

  Future<List<Row>> _rows(String table) async {
    final result = await db
        .customSelect('SELECT * FROM $table ORDER BY rowid')
        .get();
    return result.map((r) {
      final row = Map<String, dynamic>.from(r.data);
      if (row.containsKey('archived')) row['archived'] = row['archived'] == 1;
      for (final key in [
        'product_snapshot',
        'store_snapshot',
        'estimate_basis_snapshot',
      ]) {
        if (row[key] is String) row[key] = jsonDecode(row[key] as String);
      }
      return row;
    }).toList();
  }

  Future<AppData> _read() async => AppData(
    products: await _rows('products'),
    stores: await _rows('stores'),
    prices: await _rows('price_records'),
    lists: await _rows('shopping_lists'),
    items: await _rows('list_items'),
    purchases: await _rows('purchases'),
    settings: {
      for (final row in await _rows('app_settings'))
        row['key'] as String: jsonDecode(row['value'] as String),
    },
    monthlyBudgets: {
      for (final row in await _rows('monthly_budgets'))
        row['month'] as String: row['budget_centavos'] as int,
    },
  );

  AppData _copy(
    AppData data, {
    List<Row>? products,
    List<Row>? stores,
    List<Row>? prices,
    List<Row>? lists,
    List<Row>? items,
    List<Row>? purchases,
    Map<String, dynamic>? settings,
    Map<String, int>? monthlyBudgets,
  }) => AppData(
    products: products ?? data.products,
    stores: stores ?? data.stores,
    prices: prices ?? data.prices,
    lists: lists ?? data.lists,
    items: items ?? data.items,
    purchases: purchases ?? data.purchases,
    settings: settings ?? data.settings,
    monthlyBudgets: monthlyBudgets ?? data.monthlyBudgets,
  );

  Row? _find(List<Row> rows, dynamic id) {
    for (final row in rows) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  List<Row> _replace(List<Row> rows, Row row) => [
    for (final existing in rows)
      if (existing['id'] != row['id']) existing,
    row,
  ];

  Row _prepare(String table, Row input, List<Row> rows, Row defaults) {
    final id = input['id'] ?? _uuid.v4();
    checkedId(id, 'Record ID');
    final existing = _find(rows, id);
    final row = <String, dynamic>{
      ...defaults,
      ...?existing,
      ...input,
      'id': id,
    };
    if (entityFields[table]!.contains('created_at_utc')) {
      final now = _clock().toUtc().toIso8601String();
      row['created_at_utc'] = existing?['created_at_utc'] ?? now;
      row['updated_at_utc'] = now;
    }
    return row;
  }

  Future<void> _upsert(String table, Row row) async {
    final fields = entityFields[table]!;
    final values = fields.map((key) {
      final value = row[key];
      if (value is bool) return value ? 1 : 0;
      if (value is Map || value is List) return jsonEncode(value);
      return value;
    }).toList();
    final updates = fields
        .where((key) => key != 'id')
        .map((key) => '$key=excluded.$key')
        .join(',');
    await db.customStatement(
      'INSERT INTO $table (${fields.join(',')}) VALUES (${List.filled(fields.length, '?').join(',')}) '
      'ON CONFLICT(id) DO UPDATE SET $updates',
      values,
    );
  }

  void _validate(AppData data) => validateAppData(data, now: _clock());

  Future<void> saveProduct(Row input) => db.transaction(() async {
    final data = await _read();
    final row = _prepare('products', input, data.products, {
      'brand': '',
      'variant_grade': '',
      'category': 'Uncategorized',
      'archived': false,
    });
    final existing = _find(data.products, row['id']);
    final referenced = [
      ...data.prices,
      ...data.items,
      ...data.purchases,
    ].any((r) => r['product_id'] == row['id']);
    if (existing != null &&
        referenced &&
        existing['quantity_kind'] != row['quantity_kind']) {
      invalid(
        'Create a new product to use another quantity kind. Existing records must retain their meaning.',
      );
    }
    _validate(_copy(data, products: _replace(data.products, row)));
    await _upsert('products', row);
  });

  Future<void> saveStore(Row input) => db.transaction(() async {
    final data = await _read();
    final row = _prepare('stores', input, data.stores, {
      'barangay_text': null,
      'landmark': null,
      'archived': false,
    });
    _validate(_copy(data, stores: _replace(data.stores, row)));
    await _upsert('stores', row);
  });

  Future<void> savePrice(Row input) => db.transaction(() async {
    final data = await _read();
    final row = _prepare('price_records', input, data.prices, {
      'selling_mode': 'loose',
      'offer_type': 'regular',
      'source_type': 'observed',
      'notes': '',
    });
    final existing = _find(data.prices, row['id']);
    if (existing != null &&
        existing['product_id'] != row['product_id'] &&
        data.items.any((i) => i['source_price_id'] == row['id'])) {
      invalid(
        'A selected source price cannot be moved to another product. Create a new record.',
      );
    }
    _validate(_copy(data, prices: _replace(data.prices, row)));
    await _upsert('price_records', row);
  });

  Future<void> saveList(Row input) => db.transaction(() async {
    final data = await _read();
    final row = _prepare('shopping_lists', input, data.lists, {
      'budget_centavos': null,
      'status': 'active',
    });
    _validate(_copy(data, lists: _replace(data.lists, row)));
    await _upsert('shopping_lists', row);
  });

  Future<void> saveItem(
    Row input, {
    bool confirmManualEstimate = false,
  }) => db.transaction(() async {
    final data = await _read();
    final row = _prepare('list_items', input, data.items, {
      'estimate_mode': 'none',
      'estimate_total_centavos': null,
      'source_price_id': null,
      'estimate_basis_snapshot': null,
      'status': 'needed',
      'display_order': data.items.length,
    });
    final existing = _find(data.items, row['id']);
    if (existing?['status'] == 'bought' &&
        (row['product_id'] != existing?['product_id'] ||
            row['status'] != 'bought' ||
            row['list_id'] != existing?['list_id'])) {
      invalid(
        'Use purchase editing or confirmed undo to change a bought item.',
      );
    }
    if (row['status'] == 'bought' && existing?['status'] != 'bought') {
      invalid('Record an actual purchase to mark this item bought.');
    }
    if (existing != null && existing['product_id'] != row['product_id']) {
      if (input['estimate_mode'] == 'price' &&
          input['source_price_id'] != null) {
        // A new explicit choice may supply a fresh basis, but an inherited
        // snapshot from the previous product must never be reused.
        row['estimate_basis_snapshot'] = input['estimate_basis_snapshot'];
      } else if (!(input['estimate_mode'] == 'manual' &&
          confirmManualEstimate)) {
        row.addAll({
          'estimate_mode': 'none',
          'estimate_total_centavos': null,
          'source_price_id': null,
          'estimate_basis_snapshot': null,
        });
      }
    }
    final quantityChanged =
        existing != null &&
        existing['requested_quantity_base'] != row['requested_quantity_base'];
    if (row['estimate_mode'] == 'manual' &&
        quantityChanged &&
        !confirmManualEstimate) {
      row.addAll({
        'estimate_mode': 'none',
        'estimate_total_centavos': null,
        'source_price_id': null,
        'estimate_basis_snapshot': null,
      });
    } else if (row['estimate_mode'] == 'price') {
      if (existing != null &&
          existing['source_price_id'] != row['source_price_id'] &&
          !input.containsKey('estimate_basis_snapshot')) {
        row['estimate_basis_snapshot'] = null;
      }
      if (row['estimate_basis_snapshot'] == null) {
        final price = _find(data.prices, row['source_price_id']);
        if (price == null || price['product_id'] != row['product_id']) {
          invalid('Choose a saved price for this product.');
        }
        final product = data.product(row['product_id'] as String);
        final store = data.store(price['store_id'] as String);
        if (store == null) invalid('The selected store is missing.');
        row['estimate_basis_snapshot'] = priceSnapshot(price, product, store);
      }
      row['estimate_total_centavos'] = estimatePrice(
        checkedMap(row['estimate_basis_snapshot'], 'Estimate basis'),
        checkedInt(
          row['requested_quantity_base'],
          'Requested quantity',
          min: 1,
          max: maxQuantity,
        ),
      ).totalCentavos;
    } else if (row['estimate_mode'] == 'none') {
      row.addAll({
        'estimate_total_centavos': null,
        'source_price_id': null,
        'estimate_basis_snapshot': null,
      });
    } else if (row['estimate_mode'] == 'manual') {
      row.addAll({'source_price_id': null, 'estimate_basis_snapshot': null});
    }
    _validate(_copy(data, items: _replace(data.items, row)));
    await _upsert('list_items', row);
  });

  Row _productSnapshot(Row product) => {
    for (final key in [
      'name',
      'brand',
      'variant_grade',
      'category',
      'quantity_kind',
    ])
      key: product[key],
  };
  Row? _storeSnapshot(Row? store) => store == null
      ? null
      : {
          for (final key in ['name', 'barangay_text', 'landmark'])
            key: store[key],
        };

  Future<void> savePurchase(Row input) => db.transaction(() async {
    final data = await _read();
    var existing = _find(data.purchases, input['id']);
    final linkedId = input.containsKey('list_item_id')
        ? input['list_item_id']
        : existing?['list_item_id'];
    Row? item;
    if (linkedId != null) {
      item = _find(data.items, linkedId);
      if (item == null) invalid('The shopping-list item no longer exists.');
      final linkedPurchase = data.purchaseFor(linkedId as String);
      if (existing != null &&
          linkedPurchase != null &&
          existing['id'] != linkedPurchase['id']) {
        invalid('This item already has a different purchase.');
      }
      existing ??= linkedPurchase;
    }
    if (existing != null && existing['list_item_id'] != linkedId) {
      invalid('A purchase cannot be moved between list items.');
    }
    final merged = <String, dynamic>{
      ...?existing,
      ...input,
      if (existing != null) 'id': existing['id'],
    };
    final row = _prepare('purchases', merged, data.purchases, {
      'list_item_id': null,
      'store_id': null,
      'product_snapshot': null,
      'store_snapshot': null,
    });
    final product = _find(data.products, row['product_id']);
    if (product == null) invalid('Choose an existing product.');
    if (existing != null && existing['product_id'] != row['product_id']) {
      invalid('Create a new purchase to use a different product.');
    }
    row['product_snapshot'] =
        existing?['product_snapshot'] ?? _productSnapshot(product);
    final store = row['store_id'] == null
        ? null
        : _find(data.stores, row['store_id']);
    if (row['store_id'] != null && store == null) {
      invalid('Choose an existing store.');
    }
    row['store_snapshot'] =
        existing != null && existing['store_id'] == row['store_id']
        ? existing['store_snapshot']
        : _storeSnapshot(store);
    final items = item == null
        ? data.items
        : _replace(data.items, {...item, 'status': 'bought'});
    _validate(
      _copy(data, purchases: _replace(data.purchases, row), items: items),
    );
    await _upsert('purchases', row);
    writeCheckpoint?.call('purchase_written');
    if (item != null) {
      await _upsert('list_items', {...item, 'status': 'bought'});
    }
  });

  Future<void> deletePrice(String id) => db.transaction(() async {
    checkedId(id, 'Price ID');
    await db.customStatement('DELETE FROM price_records WHERE id=?', [id]);
  });

  Future<void> deleteItem(String id) => db.transaction(() async {
    final data = await _read();
    final item = _find(data.items, id);
    if (item == null) invalid('The item no longer exists.');
    if (item['status'] == 'bought' || data.purchaseFor(id) != null) {
      invalid('Undo the purchase before deleting this item.');
    }
    await db.customStatement('DELETE FROM list_items WHERE id=?', [id]);
  });

  Future<void> deletePurchase(String id) => db.transaction(() async {
    final data = await _read();
    final purchase = _find(data.purchases, id);
    if (purchase == null) return;
    await db.customStatement('DELETE FROM purchases WHERE id=?', [id]);
    writeCheckpoint?.call('purchase_deleted');
    if (purchase['list_item_id'] != null) {
      await db.customStatement(
        "UPDATE list_items SET status='needed' WHERE id=?",
        [purchase['list_item_id']],
      );
    }
  });

  Future<String> duplicateList(String listId) => db.transaction(() async {
    final data = await _read();
    final original = _find(data.lists, listId);
    if (original == null) invalid('The list no longer exists.');
    final row = _prepare(
      'shopping_lists',
      {
        'title': '${original['title']} (copy)',
        'budget_centavos': original['budget_centavos'],
      },
      [],
      {'status': 'active'},
    );
    if ((row['title'] as String).length > 200) {
      row['title'] =
          '${(original['title'] as String).substring(0, 193)} (copy)';
    }
    final items = [
      for (final item in data.listItems(listId))
        <String, dynamic>{
          ...item,
          'id': _uuid.v4(),
          'list_id': row['id'],
          'status': 'needed',
          'estimate_mode': 'none',
          'estimate_total_centavos': null,
          'source_price_id': null,
          'estimate_basis_snapshot': null,
        },
    ];
    _validate(
      _copy(
        data,
        lists: [...data.lists, row],
        items: [...data.items, ...items],
      ),
    );
    await _upsert('shopping_lists', row);
    for (final item in items) {
      await _upsert('list_items', item);
    }
    return row['id'] as String;
  });

  Future<void> setSetting(
    String key,
    dynamic value,
  ) => db.transaction(() async {
    validateSetting(key, value);
    await db.customStatement(
      'INSERT INTO app_settings(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
      [key, jsonEncode(value)],
    );
  });

  Future<void> setMonthlyBudget(
    String month,
    int? centavos,
  ) => db.transaction(() async {
    checkedMonth(month);
    if (centavos == null) {
      await db.customStatement('DELETE FROM monthly_budgets WHERE month=?', [
        month,
      ]);
    } else {
      checkedInt(centavos, 'Monthly budget', max: maxBudget);
      await db.customStatement(
        'INSERT INTO monthly_budgets(month,budget_centavos) VALUES (?,?) ON CONFLICT(month) DO UPDATE SET budget_centavos=excluded.budget_centavos',
        [month, centavos],
      );
    }
  });

  Future<void> _clear() async {
    for (final table in [
      'purchases',
      'list_items',
      'price_records',
      'shopping_lists',
      'products',
      'stores',
      'app_settings',
      'monthly_budgets',
    ]) {
      await db.customStatement('DELETE FROM $table');
    }
  }

  Future<void> reset() => db.transaction(_clear);

  Future<void> restore(AppData data, {void Function()? beforeCommit}) async {
    if (isDemo) {
      invalid('Switch to your real notebook before restoring a backup.');
    }
    _validate(data);
    await db.transaction(() async {
      await _clear();
      writeCheckpoint?.call('restore_after_clear');
      for (final entry in <String, List<Row>>{
        'products': data.products,
        'stores': data.stores,
        'price_records': data.prices,
        'shopping_lists': data.lists,
        'list_items': data.items,
        'purchases': data.purchases,
      }.entries) {
        for (final row in entry.value) {
          await _upsert(entry.key, row);
        }
        writeCheckpoint?.call('restore_${entry.key}');
      }
      for (final entry in data.settings.entries) {
        await db.customStatement(
          'INSERT INTO app_settings(key,value) VALUES (?,?)',
          [entry.key, jsonEncode(entry.value)],
        );
      }
      for (final entry in data.monthlyBudgets.entries) {
        await db.customStatement(
          'INSERT INTO monthly_budgets(month,budget_centavos) VALUES (?,?)',
          [entry.key, entry.value],
        );
      }
      beforeCommit?.call();
      final violations = await db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (violations.isNotEmpty) {
        invalid('Restored data contains invalid references.');
      }
    });
  }

  Future<void> seedDemo() => db.transaction(() async {
    if (!isDemo) invalid('Fictional data is allowed only in demo mode.');
    if ((await _read()).products.isNotEmpty) return;
    final productId = _uuid.v4();
    final storeA = _uuid.v4();
    final storeB = _uuid.v4();
    await saveProduct({
      'id': productId,
      'name': 'Demo tomatoes',
      'category': 'Vegetables',
      'variant_grade': 'Sample medium',
      'quantity_kind': 'mass',
    });
    await saveStore({'id': storeA, 'name': 'Demo Stall A'});
    await saveStore({'id': storeB, 'name': 'Demo Stall B'});
    final date = dateText(manilaToday(_clock()));
    await savePrice({
      'product_id': productId,
      'store_id': storeA,
      'quoted_centavos': 4500,
      'offered_quantity_base': 500,
      'observed_on': date,
      'selling_mode': 'packaged',
    });
    await savePrice({
      'product_id': productId,
      'store_id': storeB,
      'quoted_centavos': 8500,
      'offered_quantity_base': 1000,
      'observed_on': date,
    });
    final listId = _uuid.v4();
    await saveList({
      'id': listId,
      'title': 'Demo weekend groceries',
      'budget_centavos': 50000,
    });
    await saveItem({
      'list_id': listId,
      'product_id': productId,
      'requested_quantity_base': 750,
      'estimate_mode': 'manual',
      'estimate_total_centavos': 6750,
    });
    await setSetting('onboarding_complete', true);
  });
}
