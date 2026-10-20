import 'dart:convert';

import '../core/models.dart';
import 'validation.dart';

String encodeBackup(AppData data, {DateTime? now}) {
  validateAppData(data, now: now);
  final result = _encodeDocument(
    data,
    (now ?? DateTime.now()).toUtc().toIso8601String(),
  );
  if (utf8.encode(result).length > maxBackupBytes) {
    invalid('The backup exceeds 10 MiB. Export fewer records.');
  }
  return result;
}

/// Call after logical validation and before mutation. Reserving the longest UTC
/// timestamp keeps a notebook exportable when a later clock has microseconds.
void validateBackupCapacity(AppData data) {
  final result = _encodeDocument(data, '9999-12-31T23:59:59.999999Z');
  if (utf8.encode(result).length > maxBackupBytes) {
    invalid(
      'This change would make your complete backup larger than 10 MiB. '
      'Shorten text or back up and remove unneeded records, then try again. '
      'Nothing was saved.',
    );
  }
}

String _encodeDocument(AppData data, String exportedAtUtc) {
  final document = <String, dynamic>{
    'format_version': 2,
    'exported_at_utc': exportedAtUtc,
    'currency': 'PHP',
    'timezone': 'Asia/Manila',
    'products': data.products,
    'stores': data.stores,
    'price_records': data.prices,
    'shopping_lists': data.lists,
    'list_items': data.items,
    'purchases': data.purchases,
    'app_settings': data.settings,
    'monthly_budgets': [
      for (final entry in data.monthlyBudgets.entries)
        {'month': entry.key, 'budget_centavos': entry.value},
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(document);
}

AppData decodeBackup(String text, {DateTime? now}) {
  if (utf8.encode(text).length > maxBackupBytes) {
    invalid('The backup exceeds the 10 MiB limit.');
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    invalid('This file is not valid JSON. Select a PresyoGo JSON backup.');
  }
  final root = checkedMap(decoded, 'Backup');
  exactFields(root, [
    'format_version',
    'exported_at_utc',
    'currency',
    'timezone',
    'products',
    'stores',
    'price_records',
    'shopping_lists',
    'list_items',
    'purchases',
    'app_settings',
    'monthly_budgets',
  ], 'Backup');
  if (root['format_version'] is! int ||
      !const [1, 2].contains(root['format_version'])) {
    invalid('This backup format version is not supported.');
  }
  if (root['currency'] != 'PHP' || root['timezone'] != 'Asia/Manila') {
    invalid('The backup must use PHP and Asia/Manila.');
  }
  checkedUtc(root['exported_at_utc'], 'Backup export time');
  var count = 0;
  List<Row> rows(String key) {
    final value = root[key];
    if (value is! List) invalid('$key must be an array.');
    count += value.length;
    if (count > maxBackupRows) {
      invalid('Backup exceeds $maxBackupRows total rows.');
    }
    return value.map((row) => checkedMap(row, key)).toList();
  }

  final products = rows('products');
  final formatVersion = root['format_version'] as int;
  final stores = rows('stores').map((row) {
    if (formatVersion == 1) {
      exactFields(
        row,
        entityFields['stores']!.where(
          (field) => !storeLocationFields.contains(field),
        ),
        'Legacy store',
      );
      return <String, dynamic>{
        ...row,
        for (final field in storeLocationFields) field: null,
      };
    }
    return row;
  }).toList();
  final prices = rows('price_records');
  final lists = rows('shopping_lists');
  final items = rows('list_items');
  final purchases = rows('purchases');
  final settings = checkedMap(root['app_settings'], 'Settings');
  count += settings.length;
  final budgetRows = rows('monthly_budgets');
  if (count > maxBackupRows) {
    invalid('Backup exceeds $maxBackupRows total rows.');
  }
  final budgets = <String, int>{};
  for (final row in budgetRows) {
    exactFields(row, ['month', 'budget_centavos'], 'Monthly budget');
    if (row['month'] is! String) invalid('Month must be text.');
    final month = row['month'] as String;
    checkedMonth(month);
    if (budgets.containsKey(month)) invalid('Duplicate monthly budget.');
    budgets[month] = checkedInt(
      row['budget_centavos'],
      'Monthly budget',
      max: maxBudget,
    );
  }
  final result = AppData(
    products: products,
    stores: stores,
    prices: prices,
    lists: lists,
    items: items,
    purchases: purchases,
    settings: settings,
    monthlyBudgets: budgets,
  );
  validateAppData(result, now: now);
  return result;
}

/// Prefix an apostrophe before spreadsheet formula-like text, including controls
/// hidden in leading whitespace, then apply standard RFC4180 quoting.
String csvText(String value) {
  final trimmed = value.trimLeft();
  if ((trimmed.isNotEmpty && '=+-@'.contains(trimmed[0])) ||
      RegExp(r'^\s*[\t\r]').hasMatch(value)) {
    value = "'$value";
  }
  return '"${value.replaceAll('"', '""')}"';
}

String _csv(List<List<Object?>> rows) =>
    '${rows.map((row) => row.map((value) => value is int ? '$value' : csvText(value?.toString() ?? '')).join(',')).join('\r\n')}\r\n';

String pricesCsv(AppData data) {
  validateAppData(data);
  return _csv([
    [
      'id',
      'product',
      'brand',
      'variant_grade',
      'category',
      'quantity_kind',
      'store',
      'store_area_text',
      'store_latitude_e6',
      'store_longitude_e6',
      'store_accuracy_m',
      'store_location_captured_at_utc',
      'quoted_centavos_PHP',
      'offered_quantity_base',
      'selling_mode',
      'offer_type',
      'source_type',
      'observed_on_Asia_Manila',
      'notes',
    ],
    for (final price in data.prices)
      [
        price['id'],
        data.product(price['product_id'] as String)['name'],
        data.product(price['product_id'] as String)['brand'],
        data.product(price['product_id'] as String)['variant_grade'],
        data.product(price['product_id'] as String)['category'],
        data.product(price['product_id'] as String)['quantity_kind'],
        data.store(price['store_id'] as String)?['name'],
        for (final field in storeLocationFields)
          data.store(price['store_id'] as String)?[field],
        price['quoted_centavos'],
        price['offered_quantity_base'],
        price['selling_mode'],
        price['offer_type'],
        price['source_type'],
        price['observed_on'],
        price['notes'],
      ],
  ]);
}

String purchasesCsv(AppData data) {
  validateAppData(data);
  return _csv([
    [
      'id',
      'list_item_id',
      'product_at_purchase',
      'brand_at_purchase',
      'variant_grade_at_purchase',
      'category_at_purchase',
      'quantity_kind',
      'store_at_purchase',
      'store_area_at_purchase',
      'store_latitude_e6_at_purchase',
      'store_longitude_e6_at_purchase',
      'store_accuracy_m_at_purchase',
      'store_location_captured_at_utc_at_purchase',
      'actual_quantity_base',
      'actual_total_centavos_PHP',
      'purchased_on_Asia_Manila',
    ],
    for (final purchase in data.purchases)
      [
        purchase['id'],
        purchase['list_item_id'],
        purchase['product_snapshot']['name'],
        purchase['product_snapshot']['brand'],
        purchase['product_snapshot']['variant_grade'],
        purchase['product_snapshot']['category'],
        purchase['product_snapshot']['quantity_kind'],
        purchase['store_snapshot']?['name'],
        for (final field in storeLocationFields)
          purchase['store_snapshot']?[field],
        purchase['actual_quantity_base'],
        purchase['actual_total_centavos'],
        purchase['purchased_on'],
      ],
  ]);
}
