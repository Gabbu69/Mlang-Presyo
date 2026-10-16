/// Validated, JSON-compatible entity representation used at repository boundaries.
typedef Row = Map<String, dynamic>;

class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One immutable, consistent read of the currently selected local database.
class AppData {
  AppData({
    List<Row> products = const [],
    List<Row> stores = const [],
    List<Row> prices = const [],
    List<Row> lists = const [],
    List<Row> items = const [],
    List<Row> purchases = const [],
    Map<String, dynamic> settings = const {},
    Map<String, int> monthlyBudgets = const {},
  }) : products = _rows(products),
       stores = _rows(stores),
       prices = _rows(prices),
       lists = _rows(lists),
       items = _rows(items),
       purchases = _rows(purchases),
       settings = _freezeMap(settings),
       monthlyBudgets = Map<String, int>.unmodifiable(monthlyBudgets);

  factory AppData.empty() => AppData();

  final List<Row> products;
  final List<Row> stores;
  final List<Row> prices;
  final List<Row> lists;
  final List<Row> items;
  final List<Row> purchases;
  final Map<String, dynamic> settings;
  final Map<String, int> monthlyBudgets;

  Row product(String id) {
    for (final row in products) {
      if (row['id'] == id) return row;
    }
    throw const ValidationException('The selected product no longer exists.');
  }

  Row? store(String? id) {
    if (id == null) return null;
    for (final row in stores) {
      if (row['id'] == id) return row;
    }
    throw const ValidationException('The selected store no longer exists.');
  }

  List<Row> listItems(String listId) {
    final result = items.where((row) => row['list_id'] == listId).toList();
    result.sort((a, b) {
      final order = (a['display_order'] as int? ?? 0).compareTo(
        b['display_order'] as int? ?? 0,
      );
      return order != 0
          ? order
          : (a['id'] as String).compareTo(b['id'] as String);
    });
    return List<Row>.unmodifiable(result);
  }

  Row? purchaseFor(String itemId) {
    for (final row in purchases) {
      if (row['list_item_id'] == itemId) return row;
    }
    return null;
  }
}

List<Row> _rows(List<Row> rows) => List<Row>.unmodifiable(rows.map(_freezeMap));

Map<String, dynamic> _freezeMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.unmodifiable(
      value.map((key, entry) => MapEntry(key, _freeze(entry))),
    );

dynamic _freeze(dynamic value) {
  if (value is Map<String, dynamic>) return _freezeMap(value);
  if (value is Map) {
    return _freezeMap(
      value.map((key, entry) => MapEntry(key.toString(), entry)),
    );
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}
