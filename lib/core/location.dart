import 'dart:math' as math;

import 'models.dart';

String normalizedAreaLabel(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

bool validCoordinatePair(dynamic latitudeE6, dynamic longitudeE6) =>
    latitudeE6 is int &&
    longitudeE6 is int &&
    latitudeE6 >= -90000000 &&
    latitudeE6 <= 90000000 &&
    longitudeE6 >= -180000000 &&
    longitudeE6 <= 180000000;

/// Approximate straight-line geography only. Money/quantity arithmetic never
/// passes through these floating-point distance calculations.
double distanceMetres(int latA, int lonA, int latB, int lonB) {
  if (!validCoordinatePair(latA, lonA) || !validCoordinatePair(latB, lonB)) {
    throw const ValidationException('The saved coordinates are invalid.');
  }
  final radians = math.pi / 180 / 1000000;
  final latitudeDelta = (latB - latA) * radians;
  final longitudeDelta = (lonB - lonA) * radians;
  final a =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(latA * radians) *
          math.cos(latB * radians) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
}

String coordinateText(int latitudeE6, int longitudeE6) =>
    '${(latitudeE6 / 1000000).toStringAsFixed(6)}, '
    '${(longitudeE6 / 1000000).toStringAsFixed(6)}';

String approximateDistance(double metres) => metres < 1000
    ? 'about ${metres.round()} m away'
    : 'about ${(metres / 1000).toStringAsFixed(1)} km away';

class ShoppingArea {
  const ShoppingArea({
    this.mode = 'all',
    this.label = '',
    this.latitudeE6,
    this.longitudeE6,
    this.accuracyM,
    this.capturedAtUtc,
    this.radiusM = 10000,
  });

  factory ShoppingArea.fromSettings(Map<String, dynamic> settings) {
    final mode = settings['location_mode'];
    final label = settings['area_label'] is String
        ? (settings['area_label'] as String).trim()
        : '';
    if (mode == 'manual' && label.isNotEmpty) {
      return ShoppingArea(mode: 'manual', label: label);
    }
    final lat = settings['area_latitude_e6'];
    final lon = settings['area_longitude_e6'];
    final accuracy = settings['area_accuracy_m'];
    final captured = settings['area_captured_at_utc'];
    final timestamp =
        captured is String &&
            RegExp(
              r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
            ).hasMatch(captured)
        ? DateTime.tryParse(captured)
        : null;
    if (mode == 'nearby' &&
        validCoordinatePair(lat, lon) &&
        accuracy is int &&
        accuracy >= 1 &&
        accuracy <= 100000 &&
        timestamp != null &&
        timestamp.isUtc &&
        timestamp.year >= 1900 &&
        timestamp.toIso8601String().substring(0, 19) ==
            (captured as String).substring(0, 19)) {
      final radius = settings['area_radius_m'];
      return ShoppingArea(
        mode: 'nearby',
        label: label,
        latitudeE6: lat as int,
        longitudeE6: lon as int,
        accuracyM: accuracy,
        capturedAtUtc: timestamp.toUtc(),
        radiusM: const [5000, 10000, 25000].contains(radius)
            ? radius as int
            : 10000,
      );
    }
    // Existing installations and incomplete settings keep their whole notebook.
    return const ShoppingArea();
  }

  final String mode, label;
  final int? latitudeE6, longitudeE6, accuracyM;
  final DateTime? capturedAtUtc;
  final int radiusM;
  bool get isAll => mode == 'all';
  bool get isNearby => mode == 'nearby';
  String get description => switch (mode) {
    'manual' => 'Area: $label',
    'nearby' =>
      '${label.isEmpty ? 'Nearby saved stores' : label} · '
          '${radiusM ~/ 1000} km radius',
    _ => 'All areas',
  };
  Row toRow() => {
    'mode': mode,
    'label': mode == 'all' || label.isEmpty ? null : label,
    'latitude_e6': latitudeE6,
    'longitude_e6': longitudeE6,
    'accuracy_m': accuracyM,
    'captured_at_utc': capturedAtUtc?.toUtc().toIso8601String(),
    'radius_m': radiusM,
  };
}

double? storeDistance(ShoppingArea area, Row store) {
  if (!area.isNearby ||
      !validCoordinatePair(store['latitude_e6'], store['longitude_e6'])) {
    return null;
  }
  return distanceMetres(
    area.latitudeE6!,
    area.longitudeE6!,
    store['latitude_e6'] as int,
    store['longitude_e6'] as int,
  );
}

bool areaMatchesStore(ShoppingArea area, Row store) => switch (area.mode) {
  'manual' =>
    store['area_text'] is String &&
        normalizedAreaLabel(store['area_text'] as String) ==
            normalizedAreaLabel(area.label),
  'nearby' => (storeDistance(area, store) ?? double.infinity) <= area.radiusM,
  _ => true,
};

List<Row> pricesInArea(AppData data, ShoppingArea area) {
  if (area.isAll) return data.prices;
  final ids = data.stores
      .where((store) => areaMatchesStore(area, store))
      .map((store) => store['id'])
      .toSet();
  return data.prices.where((price) => ids.contains(price['store_id'])).toList();
}

int unlocatedStoreCount(AppData data) => data.stores
    .where(
      (store) =>
          !validCoordinatePair(store['latitude_e6'], store['longitude_e6']),
    )
    .length;
