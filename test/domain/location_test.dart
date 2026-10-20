import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:presyo_mlang/core/location.dart';
import 'package:presyo_mlang/core/models.dart';

void main() {
  test(
    'manual areas match case and collapsed whitespace without merging places',
    () {
      const area = ShoppingArea(mode: 'manual', label: '  Davao   City ');
      expect(normalizedAreaLabel('  DAVAO\n City\t'), 'davao city');
      expect(areaMatchesStore(area, {'area_text': 'davao city'}), true);
      expect(areaMatchesStore(area, {'area_text': ' Davao\tCity  '}), true);
      expect(areaMatchesStore(area, {'area_text': 'Davao del Sur'}), false);
      expect(areaMatchesStore(area, {'area_text': null}), false);
      expect(areaMatchesStore(area, {}), false);
    },
  );

  test(
    'coordinate pairs accept boundaries and reject partial, decimal or non-finite values',
    () {
      for (final pair in [
        [-90000000, -180000000],
        [90000000, 180000000],
        [0, 0],
      ]) {
        expect(validCoordinatePair(pair[0], pair[1]), true);
      }
      for (final pair in <List<dynamic>>[
        [90000001, 0],
        [-90000001, 0],
        [0, 180000001],
        [0, -180000001],
        [null, 0],
        [0, null],
        [1.5, 0],
        [0, double.nan],
        ['0', 0],
      ]) {
        expect(validCoordinatePair(pair[0], pair[1]), false);
      }
      expect(
        () => distanceMetres(90000001, 0, 0, 0),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test(
    'minimum signed int cannot bypass coordinate bounds through abs overflow',
    () {
      const minimumInt = -9223372036854775808;
      expect(validCoordinatePair(minimumInt, 0), false);
      expect(validCoordinatePair(0, minimumInt), false);
      expect(
        () => distanceMetres(minimumInt, 0, 0, 0),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => distanceMetres(0, 0, 0, minimumInt),
        throwsA(isA<ValidationException>()),
      );
      final area = ShoppingArea.fromSettings({
        'location_mode': 'nearby',
        'area_latitude_e6': minimumInt,
        'area_longitude_e6': 0,
        'area_accuracy_m': 25,
        'area_captured_at_utc': '2026-10-16T05:00:00Z',
        'area_radius_m': 10000,
      });
      expect(area.isAll, true);
      const nearby = ShoppingArea(
        mode: 'nearby',
        latitudeE6: 0,
        longitudeE6: 0,
      );
      expect(
        areaMatchesStore(nearby, {
          'latitude_e6': minimumInt,
          'longitude_e6': 0,
        }),
        false,
      );
    },
  );

  test('distance handles identical points, symmetry and the date line', () {
    expect(distanceMetres(7000000, 125000000, 7000000, 125000000), 0);
    expect(distanceMetres(0, 0, 1000000, 0), closeTo(111194.9266, 0.001));
    expect(
      distanceMetres(7000000, 125000000, 14000000, 121000000),
      closeTo(distanceMetres(14000000, 121000000, 7000000, 125000000), 0.0001),
    );
    expect(distanceMetres(0, 179999999, 0, -179999999), lessThan(1));
  });

  for (final radius in [5000, 10000, 25000]) {
    test(
      '$radius m radius includes center and nearest inside point, excludes next coordinate outside',
      () {
        // At the equator, one degree of longitude is R*pi/180 metres.
        // Integer microdegrees let us test the two points bracketing each radius.
        final edgeE6 = (radius * 180 * 1000000 / (6371000 * math.pi)).floor();
        final area = ShoppingArea(
          mode: 'nearby',
          latitudeE6: 0,
          longitudeE6: 0,
          radiusM: radius,
        );
        expect(
          areaMatchesStore(area, {'latitude_e6': 0, 'longitude_e6': 0}),
          true,
        );
        expect(
          areaMatchesStore(area, {'latitude_e6': 0, 'longitude_e6': edgeE6}),
          true,
        );
        expect(
          areaMatchesStore(area, {
            'latitude_e6': 0,
            'longitude_e6': edgeE6 + 1,
          }),
          false,
        );
        expect(
          areaMatchesStore(area, {'latitude_e6': null, 'longitude_e6': null}),
          false,
        );
        expect(areaMatchesStore(area, {'latitude_e6': 0}), false);
      },
    );
  }

  test('nearby boundary comparison is inclusive', () {
    // An exact distance of zero exercises <= independently of rounding.
    const area = ShoppingArea(
      mode: 'nearby',
      latitudeE6: 0,
      longitudeE6: 0,
      radiusM: 0,
    );
    expect(areaMatchesStore(area, {'latitude_e6': 0, 'longitude_e6': 0}), true);
    expect(
      areaMatchesStore(area, {'latitude_e6': 0, 'longitude_e6': 1}),
      false,
    );
  });

  test(
    'area filtering retains original price rows and All areas includes unlocated stores',
    () {
      final data = AppData(
        stores: [
          {
            'id': 'near',
            'area_text': 'Sample city',
            'latitude_e6': 0,
            'longitude_e6': 0,
          },
          {
            'id': 'far',
            'area_text': 'Other city',
            'latitude_e6': 1000000,
            'longitude_e6': 0,
          },
          {'id': 'unknown', 'area_text': 'Sample city'},
        ],
        prices: [
          {'id': 'one', 'store_id': 'near', 'quoted_centavos': 1200},
          {'id': 'two', 'store_id': 'far', 'quoted_centavos': 1000},
          {'id': 'three', 'store_id': 'unknown', 'quoted_centavos': 900},
        ],
      );
      const nearby = ShoppingArea(
        mode: 'nearby',
        latitudeE6: 0,
        longitudeE6: 0,
      );
      expect(pricesInArea(data, nearby), [data.prices[0]]);
      expect(
        pricesInArea(
          data,
          const ShoppingArea(mode: 'manual', label: 'SAMPLE CITY'),
        ),
        [data.prices[0], data.prices[2]],
      );
      expect(
        identical(pricesInArea(data, const ShoppingArea()), data.prices),
        true,
      );
      expect(
        pricesInArea(
          data,
          const ShoppingArea(mode: 'manual', label: 'No records'),
        ),
        isEmpty,
      );
      expect(unlocatedStoreCount(data), 1);
      expect(storeDistance(const ShoppingArea(), data.stores[0]), isNull);
    },
  );

  test(
    'legacy settings default to All areas and valid settings preserve the saved capture',
    () {
      expect(ShoppingArea.fromSettings({}).isAll, true);
      expect(
        ShoppingArea.fromSettings({
          'location_mode': 'manual',
          'area_label': '  ',
        }).isAll,
        true,
      );
      expect(
        ShoppingArea.fromSettings({'location_mode': 'unknown'}).isAll,
        true,
      );
      const manual = ShoppingArea(mode: 'manual', label: 'Sample city');
      expect(manual.toRow()['latitude_e6'], isNull);
      final settings = <String, dynamic>{
        'location_mode': 'nearby',
        'area_label': null,
        'area_latitude_e6': 7000000,
        'area_longitude_e6': 125000000,
        'area_accuracy_m': 1500,
        'area_captured_at_utc': '2026-10-16T05:00:00.000Z',
        'area_radius_m': 25000,
      };
      final area = ShoppingArea.fromSettings(settings);
      expect(area.isNearby, true);
      expect(area.radiusM, 25000);
      expect(area.capturedAtUtc, DateTime.utc(2026, 10, 16, 5));
      expect(area.toRow()['captured_at_utc'], '2026-10-16T05:00:00.000Z');
      expect(
        ShoppingArea.fromSettings({...settings, 'area_radius_m': 42}).radiusM,
        10000,
      );
      for (final changed in <Row>[
        {'area_accuracy_m': 0},
        {'area_accuracy_m': 100001},
        {'area_captured_at_utc': '2026-10-16T05:00:00'},
        {'area_captured_at_utc': '2026-02-30T05:00:00Z'},
        {'area_captured_at_utc': 'bad'},
        {'area_latitude_e6': null},
      ]) {
        expect(
          ShoppingArea.fromSettings({...settings, ...changed}).isAll,
          true,
        );
      }
    },
  );
}
