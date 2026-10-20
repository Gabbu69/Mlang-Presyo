import 'dart:convert';

import 'models.dart';

const int maxCanonicalQuantity = 1000000;
const int maxMoneyCentavos = 100000000;
const int maxBudgetCentavos = 1000000000;
final BigInt _maxInteger = BigInt.parse('9223372036854775807');

int _checked(BigInt value) {
  if (value > _maxInteger || value < -_maxInteger) {
    throw const ValidationException('The calculated total is too large.');
  }
  return value.toInt();
}

int parseMoney(
  String input, {
  bool positive = false,
  int max = maxMoneyCentavos,
}) {
  final value = input.trim();
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value) ||
      value.length > 32 ||
      max < 0) {
    throw const ValidationException(
      'Enter a nonnegative amount with at most two decimal places.',
    );
  }
  final parts = value.split('.');
  final cents =
      BigInt.parse(parts.first) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  if ((positive && cents == BigInt.zero) || cents > BigInt.from(max)) {
    throw ValidationException(
      positive && cents == BigInt.zero
          ? 'The quoted price must be greater than zero.'
          : 'The amount exceeds the allowed maximum.',
    );
  }
  return cents.toInt();
}

String money(int centavos) {
  final absolute = BigInt.from(centavos).abs();
  final whole = (absolute ~/ BigInt.from(100)).toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final cents = (absolute % BigInt.from(100)).toString().padLeft(2, '0');
  return '${centavos < 0 ? '-' : ''}₱$grouped.$cents';
}

String moneyInput(int centavos) {
  final absolute = BigInt.from(centavos).abs();
  final whole = absolute ~/ BigInt.from(100);
  final cents = (absolute % BigInt.from(100)).toString().padLeft(2, '0');
  return '${centavos < 0 ? '-' : ''}$whole.$cents';
}

String baseUnit(String kind) => switch (kind) {
  'mass' => 'g',
  'volume' => 'mL',
  'count' => 'pcs',
  _ => throw const ValidationException('Choose mass, volume, or count.'),
};

int parseQuantity(String input, String unit, String kind) {
  baseUnit(
    kind,
  ); // Validate the kind even when a supplied unit is unrecognized.
  final normalizedUnit = unit.trim().toLowerCase();
  final isLarge =
      (kind == 'mass' && normalizedUnit == 'kg') ||
      (kind == 'volume' && normalizedUnit == 'l');
  final isBase =
      (kind == 'mass' && normalizedUnit == 'g') ||
      (kind == 'volume' && normalizedUnit == 'ml') ||
      (kind == 'count' &&
          const ['pcs', 'piece', 'pieces'].contains(normalizedUnit));
  if (!isLarge && !isBase) {
    throw const ValidationException(
      'Use grams or kilograms, milliliters or liters, or whole pieces for this product.',
    );
  }
  final value = input.trim();
  final pattern = isLarge ? r'^\d+(?:\.\d{1,3})?$' : r'^\d+$';
  if (!RegExp(pattern).hasMatch(value) || value.length > 32) {
    throw ValidationException(
      isLarge
          ? 'Enter a positive quantity with at most three decimal places.'
          : 'Enter a positive whole number of ${baseUnit(kind)}.',
    );
  }
  final parts = value.split('.');
  final quantity = isLarge
      ? BigInt.parse(parts[0]) * BigInt.from(1000) +
            BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(3, '0'))
      : BigInt.parse(value);
  if (quantity <= BigInt.zero || quantity > BigInt.from(maxCanonicalQuantity)) {
    throw const ValidationException(
      'Quantity must be between 1 and 1,000,000 base units.',
    );
  }
  return quantity.toInt();
}

String quantityLabel(int quantity, String kind) =>
    '$quantity ${baseUnit(kind)}';

int roundHalfUp(int numerator, int denominator) =>
    _roundFraction(BigInt.from(numerator), BigInt.from(denominator));

int _roundFraction(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero || numerator < BigInt.zero) {
    throw const ValidationException(
      'Rounding requires a nonnegative amount and a positive quantity.',
    );
  }
  final quotient = numerator ~/ denominator;
  final remainder = numerator % denominator;
  return _checked(
    quotient +
        (remainder * BigInt.two >= denominator ? BigInt.one : BigInt.zero),
  );
}

/// A UTC midnight container for a nominal Asia/Manila calendar date.
/// The input is an instant, never a device-local calendar date.
DateTime manilaToday([DateTime? instant]) {
  final manila = (instant ?? DateTime.now()).toUtc().add(
    const Duration(hours: 8),
  );
  return DateTime.utc(manila.year, manila.month, manila.day);
}

String dateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Newest updated record first, independent of valid ISO fractional precision.
int compareUpdatedRows(Row a, Row b) {
  final updated = DateTime.parse(
    b['updated_at_utc'] as String,
  ).compareTo(DateTime.parse(a['updated_at_utc'] as String));
  return updated != 0
      ? updated
      : (a['id'] as String).compareTo(b['id'] as String);
}

DateTime _calendarDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const ValidationException('Enter a date as YYYY-MM-DD.');
  }
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final date = DateTime.utc(year, month, day);
  if (year < 1 || date.year != year || date.month != month || date.day != day) {
    throw const ValidationException('Enter a valid calendar date.');
  }
  return date;
}

void validateDate(String value, {DateTime? now}) {
  if (_calendarDate(value).isAfter(manilaToday(now))) {
    throw const ValidationException('The date cannot be in the future.');
  }
}

int ageDays(String observedOn, {DateTime? now}) {
  validateDate(observedOn, now: now);
  return manilaToday(now).difference(_calendarDate(observedOn)).inDays;
}

String ageLabel(String observedOn, {DateTime? now}) {
  final age = ageDays(observedOn, now: now);
  if (age == 0) return 'Today';
  if (age <= 7) return 'Recent record';
  if (age <= 30) return 'Older record';
  return 'Old record';
}

/// Select the latest offer before filtering and ranking its exact unit value.
List<Row> comparablePrices(
  Iterable<Row> prices,
  String productId, {
  bool older = false,
  DateTime? now,
}) {
  final latest = <String, Row>{};
  for (final price in prices) {
    if (price['product_id'] != productId) continue;
    final group = jsonEncode([
      price['store_id'],
      price['offered_quantity_base'],
      price['selling_mode'],
      price['offer_type'],
    ]);
    final previous = latest[group];
    if (previous == null || _compareObservation(price, previous) > 0) {
      latest[group] = price;
    }
  }
  final result = latest.values.where((price) {
    if (price['offer_type'] != 'regular') return false;
    _validateQuote(price);
    final age = ageDays(price['observed_on'] as String, now: now);
    return older || age <= 7;
  }).toList();
  result.sort((a, b) {
    _validateQuote(a);
    _validateQuote(b);
    final left =
        BigInt.from(a['quoted_centavos'] as int) *
        BigInt.from(b['offered_quantity_base'] as int);
    final right =
        BigInt.from(b['quoted_centavos'] as int) *
        BigInt.from(a['offered_quantity_base'] as int);
    final value = left.compareTo(right);
    return value != 0
        ? value
        : (a['id'] as String).compareTo(b['id'] as String);
  });
  return result;
}

int _compareObservation(Row a, Row b) {
  final date = (a['observed_on'] as String).compareTo(
    b['observed_on'] as String,
  );
  if (date != 0) return date;
  final aUpdated = a['updated_at_utc'] as String? ?? '';
  final bUpdated = b['updated_at_utc'] as String? ?? '';
  // ISO8601 fractional seconds can have different lengths, so compare instants.
  final timestamp = aUpdated.isEmpty || bUpdated.isEmpty
      ? aUpdated.compareTo(bUpdated)
      : DateTime.parse(aUpdated).compareTo(DateTime.parse(bUpdated));
  return timestamp != 0
      ? timestamp
      : (a['id'] as String).compareTo(b['id'] as String);
}

void _validateQuote(Row price) {
  final amount = price['quoted_centavos'];
  final quantity = price['offered_quantity_base'];
  if (amount is! int ||
      amount <= 0 ||
      amount > maxMoneyCentavos ||
      quantity is! int ||
      quantity <= 0 ||
      quantity > maxCanonicalQuantity) {
    throw const ValidationException(
      'The saved quote has an invalid amount or quantity.',
    );
  }
}

int normalizedCentavos(Row price, String kind) {
  _validateQuote(price);
  baseUnit(kind);
  final factor = kind == 'count' ? 1 : 1000;
  return _roundFraction(
    BigInt.from(price['quoted_centavos'] as int) * BigInt.from(factor),
    BigInt.from(price['offered_quantity_base'] as int),
  );
}

class Estimate {
  const Estimate({
    required this.totalCentavos,
    required this.packages,
    required this.extraQuantity,
  });

  final int totalCentavos;
  final int? packages;
  final int extraQuantity;
}

Estimate estimatePrice(Row basis, int requestedQuantity) {
  _validateQuote(basis);
  if (requestedQuantity <= 0 || requestedQuantity > maxCanonicalQuantity) {
    throw const ValidationException('Enter a valid requested quantity.');
  }
  final amount = BigInt.from(basis['quoted_centavos'] as int);
  final offered = BigInt.from(basis['offered_quantity_base'] as int);
  final requested = BigInt.from(requestedQuantity);
  if (basis['selling_mode'] == 'loose') {
    return Estimate(
      totalCentavos: _roundFraction(amount * requested, offered),
      packages: null,
      extraQuantity: 0,
    );
  }
  if (basis['selling_mode'] != 'packaged') {
    throw const ValidationException('Choose loose or packaged selling mode.');
  }
  final packages = (requested + offered - BigInt.one) ~/ offered;
  return Estimate(
    totalCentavos: _checked(packages * amount),
    packages: _checked(packages),
    extraQuantity: _checked(packages * offered - requested),
  );
}

Row priceSnapshot(Row price, Row product, Row store) => {
  'format_version': 1,
  'quoted_centavos': price['quoted_centavos'],
  'offered_quantity_base': price['offered_quantity_base'],
  'selling_mode': price['selling_mode'],
  'offer_type': price['offer_type'],
  'source_type': price['source_type'],
  'observed_on': price['observed_on'],
  'product_id': product['id'],
  'product_name': product['name'],
  'brand': product['brand'] ?? '',
  'variant_grade': product['variant_grade'] ?? '',
  'category': product['category'],
  'quantity_kind': product['quantity_kind'],
  'store_id': store['id'],
  'store_name': store['name'],
  'store_area_text': store['area_text'],
  'store_latitude_e6': store['latitude_e6'],
  'store_longitude_e6': store['longitude_e6'],
  'store_accuracy_m': store['accuracy_m'],
  'store_location_captured_at_utc': store['location_captured_at_utc'],
};

class ListTotals {
  const ListTotals({
    required this.actualSpent,
    required this.remainingEstimate,
    required this.projectedTotal,
    required this.missingEstimates,
    required this.budgetLeft,
    required this.projectedBalance,
  });

  final int actualSpent;
  final int remainingEstimate;
  final int projectedTotal;
  final int missingEstimates;
  final int? budgetLeft;

  /// Null when no budget exists or any Needed item still lacks an estimate.
  final int? projectedBalance;
}

ListTotals listTotals(AppData data, String listId) {
  final lists = data.lists.where((row) => row['id'] == listId);
  if (lists.isEmpty) {
    throw const ValidationException(
      'The selected shopping list no longer exists.',
    );
  }
  final list = lists.single;
  final items = data.listItems(listId);
  final ids = items.map((row) => row['id']).toSet();
  final actual = _sum(
    data.purchases
        .where(
          (row) =>
              row['list_item_id'] != null && ids.contains(row['list_item_id']),
        )
        .map((row) => row['actual_total_centavos'] as int),
  );
  final needed = items.where((row) => row['status'] == 'needed');
  final missing = needed
      .where((row) => row['estimate_total_centavos'] == null)
      .length;
  final remaining = _sum(
    needed
        .where((row) => row['estimate_total_centavos'] != null)
        .map((row) => row['estimate_total_centavos'] as int),
  );
  final projected = _sum([actual, remaining]);
  final budget = list['budget_centavos'] as int?;
  return ListTotals(
    actualSpent: actual,
    remainingEstimate: remaining,
    projectedTotal: projected,
    missingEstimates: missing,
    budgetLeft: budget == null ? null : _sum([budget, -actual]),
    projectedBalance: budget == null || missing > 0
        ? null
        : _sum([budget, -projected]),
  );
}

int _sum(Iterable<int> values) => _checked(
  values.fold(BigInt.zero, (sum, value) => sum + BigInt.from(value)),
);

void _validateMonth(String month) {
  if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month) ||
      month.startsWith('0000')) {
    throw const ValidationException('Choose a calendar month as YYYY-MM.');
  }
}

int monthlySpent(AppData data, String month) {
  _validateMonth(month);
  return _sum(
    data.purchases
        .where((row) => (row['purchased_on'] as String).startsWith('$month-'))
        .map((row) => row['actual_total_centavos'] as int),
  );
}

Map<String, int> categoryTotals(AppData data, String month) {
  _validateMonth(month);
  final totals = <String, int>{};
  for (final purchase in data.purchases) {
    if (!(purchase['purchased_on'] as String).startsWith('$month-')) continue;
    final snapshotValue = purchase['product_snapshot'];
    final snapshot = snapshotValue is String
        ? jsonDecode(snapshotValue) as Map<String, dynamic>
        : snapshotValue as Map<String, dynamic>;
    final category = snapshot['category'] as String? ?? 'Uncategorized';
    totals[category] = _sum([
      totals[category] ?? 0,
      purchase['actual_total_centavos'] as int,
    ]);
  }
  return totals;
}
