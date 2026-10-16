import 'dart:convert';

import '../core/domain.dart';
import '../core/models.dart';

const maxBackupBytes = 10 * 1024 * 1024;
const maxBackupRows = 20000;
const maxMoney = 100000000;
const maxBudget = 1000000000;
const maxQuantity = 1000000;

const entityFields = <String, List<String>>{
  'products': [
    'id',
    'name',
    'brand',
    'variant_grade',
    'category',
    'quantity_kind',
    'archived',
    'created_at_utc',
    'updated_at_utc',
  ],
  'stores': [
    'id',
    'name',
    'barangay_text',
    'landmark',
    'archived',
    'created_at_utc',
    'updated_at_utc',
  ],
  'price_records': [
    'id',
    'product_id',
    'store_id',
    'quoted_centavos',
    'offered_quantity_base',
    'selling_mode',
    'offer_type',
    'source_type',
    'observed_on',
    'notes',
    'created_at_utc',
    'updated_at_utc',
  ],
  'shopping_lists': [
    'id',
    'title',
    'budget_centavos',
    'status',
    'created_at_utc',
    'updated_at_utc',
  ],
  'list_items': [
    'id',
    'list_id',
    'product_id',
    'requested_quantity_base',
    'estimate_mode',
    'estimate_total_centavos',
    'source_price_id',
    'estimate_basis_snapshot',
    'status',
    'display_order',
  ],
  'purchases': [
    'id',
    'list_item_id',
    'product_id',
    'store_id',
    'actual_quantity_base',
    'actual_total_centavos',
    'purchased_on',
    'product_snapshot',
    'store_snapshot',
    'created_at_utc',
    'updated_at_utc',
  ],
};

Never invalid(String message) => throw ValidationException(message);

void exactFields(Row row, Iterable<String> fields, String context) {
  final expected = fields.toSet();
  if (row.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(row.keys.toSet()).isNotEmpty) {
    invalid('$context contains missing or unsupported fields.');
  }
}

String checkedText(
  dynamic value,
  String label, {
  bool empty = false,
  int max = 200,
}) {
  if (value is! String ||
      (!empty && value.trim().isEmpty) ||
      value.length > max ||
      value.contains('\u0000')) {
    invalid(
      '$label must be ${empty ? 'text' : 'non-empty text'} of at most $max characters.',
    );
  }
  return value;
}

int checkedInt(dynamic value, String label, {int min = 0, int max = maxMoney}) {
  if (value is! int || value < min || value > max) {
    invalid('$label must be a whole number from $min to $max.');
  }
  return value;
}

void checkedId(dynamic value, String label, {bool nullable = false}) {
  if (nullable && value == null) return;
  if (value is! String ||
      value.length != 36 ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    invalid('$label must be a UUID.');
  }
}

void checkedEnum(dynamic value, String label, List<String> options) {
  if (value is! String || !options.contains(value)) {
    invalid('$label must be one of ${options.join(', ')}.');
  }
}

void checkedUtc(dynamic value, String label) {
  if (value is! String ||
      !value.endsWith('Z') ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
      ).hasMatch(value)) {
    invalid('$label must be an ISO8601 UTC timestamp ending in Z.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      parsed.year < 1900 ||
      parsed.year > 9999 ||
      parsed.toIso8601String().substring(0, 19) != value.substring(0, 19)) {
    invalid('$label is invalid.');
  }
}

void checkedMonth(String month) {
  if (month.length != 7 ||
      !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month) ||
      int.parse(month.substring(0, 4)) < 1900) {
    invalid('Month must use YYYY-MM.');
  }
}

Row checkedMap(dynamic value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    invalid('$label must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

void validateSetting(String key, dynamic value) {
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,63}$').hasMatch(key)) {
    invalid('Unsupported setting name.');
  }
  if (value != null && value is! String && value is! bool && value is! int) {
    invalid('Setting values must be text, booleans, whole numbers, or null.');
  }
  if (value is String) {
    checkedText(value, 'Setting value', empty: true, max: 2000);
  }
  if (value is int && value.abs() > 9007199254740991) {
    invalid('Setting number is too large.');
  }
}

void validateProductSnapshot(dynamic value) {
  final row = checkedMap(value, 'Product snapshot');
  exactFields(row, [
    'name',
    'brand',
    'variant_grade',
    'category',
    'quantity_kind',
  ], 'Product snapshot');
  checkedText(row['name'], 'Snapshot product name');
  checkedText(row['brand'], 'Snapshot brand', empty: true);
  checkedText(row['variant_grade'], 'Snapshot variant', empty: true);
  checkedText(row['category'], 'Snapshot category');
  checkedEnum(row['quantity_kind'], 'Snapshot quantity kind', [
    'mass',
    'volume',
    'count',
  ]);
}

void validateStoreSnapshot(dynamic value) {
  final row = checkedMap(value, 'Store snapshot');
  exactFields(row, ['name', 'barangay_text', 'landmark'], 'Store snapshot');
  checkedText(row['name'], 'Snapshot store name');
  for (final key in ['barangay_text', 'landmark']) {
    if (row[key] != null) {
      checkedText(row[key], 'Snapshot $key', empty: true, max: 500);
    }
  }
}

void validateEstimateSnapshot(dynamic value, Row product, {DateTime? now}) {
  final row = checkedMap(value, 'Estimate snapshot');
  const required = [
    'format_version',
    'quoted_centavos',
    'offered_quantity_base',
    'selling_mode',
    'observed_on',
    'product_name',
    'store_name',
  ];
  const optional = [
    'product_id',
    'quantity_kind',
    'category',
    'brand',
    'variant_grade',
    'store_id',
    'offer_type',
    'source_type',
  ];
  if (required.any((key) => !row.containsKey(key)) ||
      row.keys.any(
        (key) => !required.contains(key) && !optional.contains(key),
      )) {
    invalid('Estimate snapshot has missing or unsupported fields.');
  }
  if (row['format_version'] != 1 || row['format_version'] is! int) {
    invalid('Unsupported estimate snapshot version.');
  }
  checkedInt(row['quoted_centavos'], 'Snapshot quote', min: 1);
  checkedInt(
    row['offered_quantity_base'],
    'Snapshot quantity',
    min: 1,
    max: maxQuantity,
  );
  checkedEnum(row['selling_mode'], 'Snapshot selling mode', [
    'loose',
    'packaged',
  ]);
  validateDate(
    row['observed_on'] is String ? row['observed_on'] as String : '',
    now: now,
  );
  checkedText(row['product_name'], 'Snapshot product name');
  checkedText(row['store_name'], 'Snapshot store name');
  if (row.containsKey('product_id')) {
    checkedId(row['product_id'], 'Snapshot product');
    if (row['product_id'] != product['id']) {
      invalid('Estimate snapshot belongs to another product.');
    }
  }
  if (row.containsKey('quantity_kind') &&
      row['quantity_kind'] != product['quantity_kind']) {
    invalid('Estimate snapshot quantity kind differs from its product.');
  }
  for (final key in ['category', 'brand', 'variant_grade']) {
    if (row.containsKey(key)) {
      checkedText(row[key], 'Snapshot $key', empty: key != 'category');
    }
  }
  if (row.containsKey('store_id')) checkedId(row['store_id'], 'Snapshot store');
  if (row.containsKey('offer_type')) {
    checkedEnum(row['offer_type'], 'Snapshot offer type', [
      'regular',
      'promotional',
      'conditional',
    ]);
  }
  if (row.containsKey('source_type')) {
    checkedEnum(row['source_type'], 'Snapshot source type', [
      'observed',
      'purchase',
      'seller_quote',
    ]);
  }
}

/// Validates logical records before SQL or restore. It never mutates the input.
void validateAppData(AppData data, {DateTime? now}) {
  final groups = <String, List<Row>>{
    'products': data.products,
    'stores': data.stores,
    'price_records': data.prices,
    'shopping_lists': data.lists,
    'list_items': data.items,
    'purchases': data.purchases,
  };
  final rowCount =
      groups.values.fold<int>(0, (sum, rows) => sum + rows.length) +
      data.settings.length +
      data.monthlyBudgets.length;
  if (rowCount > maxBackupRows) {
    invalid('Backup exceeds $maxBackupRows total rows.');
  }
  final maps = <String, Map<String, Row>>{};
  final allIds = <String>{};
  for (final entry in groups.entries) {
    final byId = <String, Row>{};
    for (final row in entry.value) {
      exactFields(row, entityFields[entry.key]!, entry.key);
      checkedId(row['id'], '${entry.key} ID');
      final id = (row['id'] as String).toLowerCase();
      if (!allIds.add(id)) invalid('Duplicate entity ID in backup.');
      byId[row['id'] as String] = row;
      if (row.containsKey('created_at_utc')) {
        checkedUtc(row['created_at_utc'], 'Creation time');
        checkedUtc(row['updated_at_utc'], 'Update time');
        if (DateTime.parse(
          row['updated_at_utc'] as String,
        ).isBefore(DateTime.parse(row['created_at_utc'] as String))) {
          invalid('Update time precedes creation time.');
        }
      }
    }
    maps[entry.key] = byId;
  }
  Row ref(String table, dynamic id, String label) {
    checkedId(id, label);
    return maps[table]![id] ?? invalid('$label refers to a missing record.');
  }

  for (final row in data.products) {
    checkedText(row['name'], 'Product name');
    checkedText(row['brand'], 'Brand', empty: true);
    checkedText(row['variant_grade'], 'Variant/grade', empty: true);
    checkedText(row['category'], 'Category');
    checkedEnum(row['quantity_kind'], 'Quantity kind', [
      'mass',
      'volume',
      'count',
    ]);
    if (row['archived'] is! bool) {
      invalid('Product archive state must be boolean.');
    }
  }
  for (final row in data.stores) {
    checkedText(row['name'], 'Store name');
    for (final key in ['barangay_text', 'landmark']) {
      if (row[key] != null) checkedText(row[key], key, empty: true, max: 500);
    }
    if (row['archived'] is! bool) {
      invalid('Store archive state must be boolean.');
    }
  }
  for (final row in data.prices) {
    ref('products', row['product_id'], 'Price product');
    ref('stores', row['store_id'], 'Price store');
    checkedInt(row['quoted_centavos'], 'Quote', min: 1);
    checkedInt(
      row['offered_quantity_base'],
      'Offered quantity',
      min: 1,
      max: maxQuantity,
    );
    checkedEnum(row['selling_mode'], 'Selling mode', ['loose', 'packaged']);
    checkedEnum(row['offer_type'], 'Offer type', [
      'regular',
      'promotional',
      'conditional',
    ]);
    checkedEnum(row['source_type'], 'Source type', [
      'observed',
      'purchase',
      'seller_quote',
    ]);
    validateDate(
      row['observed_on'] is String ? row['observed_on'] as String : '',
      now: now,
    );
    checkedText(row['notes'], 'Notes', empty: true, max: 1000);
  }
  for (final row in data.lists) {
    checkedText(row['title'], 'List title');
    if (row['budget_centavos'] != null) {
      checkedInt(row['budget_centavos'], 'List budget', max: maxBudget);
    }
    checkedEnum(row['status'], 'List status', ['active', 'archived']);
  }
  for (final row in data.items) {
    ref('shopping_lists', row['list_id'], 'Item list');
    final product = ref('products', row['product_id'], 'Item product');
    checkedInt(
      row['requested_quantity_base'],
      'Requested quantity',
      min: 1,
      max: maxQuantity,
    );
    checkedInt(row['display_order'], 'Display order', max: 1000000);
    checkedEnum(row['status'], 'Item status', ['needed', 'bought', 'skipped']);
    checkedEnum(row['estimate_mode'], 'Estimate mode', [
      'none',
      'manual',
      'price',
    ]);
    if (row['estimate_mode'] == 'none') {
      if (row['estimate_total_centavos'] != null ||
          row['source_price_id'] != null ||
          row['estimate_basis_snapshot'] != null) {
        invalid('An unestimated item must not contain an estimate.');
      }
    } else if (row['estimate_mode'] == 'manual') {
      checkedInt(row['estimate_total_centavos'], 'Manual estimate');
      if (row['source_price_id'] != null ||
          row['estimate_basis_snapshot'] != null) {
        invalid('Manual estimates cannot contain a selected-price basis.');
      }
    } else {
      validateEstimateSnapshot(
        row['estimate_basis_snapshot'],
        product,
        now: now,
      );
      final snapshot = checkedMap(
        row['estimate_basis_snapshot'],
        'Estimate snapshot',
      );
      validateDate(snapshot['observed_on'] as String, now: now);
      final expected = estimatePrice(
        snapshot,
        row['requested_quantity_base'] as int,
      ).totalCentavos;
      if (row['estimate_total_centavos'] is! int ||
          row['estimate_total_centavos'] != expected) {
        invalid('Selected-price estimate does not match its frozen basis.');
      }
      if (row['source_price_id'] != null) {
        final price = ref(
          'price_records',
          row['source_price_id'],
          'Source price',
        );
        if (price['product_id'] != row['product_id']) {
          invalid('Selected price belongs to another product.');
        }
      }
    }
  }
  final linked = <String>{};
  for (final row in data.purchases) {
    final product = ref('products', row['product_id'], 'Purchase product');
    if (row['store_id'] != null) {
      ref('stores', row['store_id'], 'Purchase store');
    }
    checkedInt(
      row['actual_quantity_base'],
      'Actual quantity',
      min: 1,
      max: maxQuantity,
    );
    checkedInt(row['actual_total_centavos'], 'Actual amount');
    validateDate(
      row['purchased_on'] is String ? row['purchased_on'] as String : '',
      now: now,
    );
    validateProductSnapshot(row['product_snapshot']);
    final snapshot = checkedMap(row['product_snapshot'], 'Product snapshot');
    if (snapshot['quantity_kind'] != product['quantity_kind']) {
      invalid('Purchase snapshot quantity kind differs from its product.');
    }
    if (row['store_id'] == null) {
      if (row['store_snapshot'] != null) {
        invalid('A purchase without a store cannot contain a store snapshot.');
      }
    } else {
      validateStoreSnapshot(row['store_snapshot']);
    }
    if (row['list_item_id'] != null) {
      final item = ref('list_items', row['list_item_id'], 'Purchase item');
      if (!linked.add(row['list_item_id'] as String)) {
        invalid('A list item cannot have two purchases.');
      }
      if (item['status'] != 'bought' ||
          item['product_id'] != row['product_id']) {
        invalid(
          'Purchase and linked item have inconsistent product or status.',
        );
      }
    }
  }
  for (final row in data.items) {
    if ((row['status'] == 'bought') != linked.contains(row['id'])) {
      invalid('Bought items require exactly one purchase.');
    }
  }
  for (final entry in data.settings.entries) {
    validateSetting(entry.key, entry.value);
  }
  for (final entry in data.monthlyBudgets.entries) {
    checkedMonth(entry.key);
    checkedInt(entry.value, 'Monthly budget', max: maxBudget);
  }
  // Ensure no non-JSON custom objects can be smuggled through settings/snapshots.
  try {
    jsonEncode({
      ...groups,
      'settings': data.settings,
      'monthly_budgets': data.monthlyBudgets,
    });
  } on JsonUnsupportedObjectError {
    invalid('Records contain unsupported values.');
  }
}
