import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/platform/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const service = LocationService();
  late Map<String, dynamic> reply;
  late List<MethodCall> calls;
  PlatformException? failure;

  setUp(() {
    calls = [];
    failure = null;
    // Fictional coordinates; the service does not infer a real person's location.
    reply = {
      'latitudeE6': 7000000,
      'longitudeE6': 125000000,
      'accuracyM': 1500,
      'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
    messenger.setMockMethodCallHandler(LocationService.channel, (call) async {
      calls.add(call);
      if (failure != null) throw failure!;
      return reply;
    });
  });

  tearDown(
    () => messenger.setMockMethodCallHandler(LocationService.channel, null),
  );

  test(
    'one explicit call accepts a recent approximate fix with its original UTC timestamp',
    () async {
      final captured = reply['capturedAtUtc'] as String;
      final fix = await service.currentLocation();
      expect(calls.single.method, 'currentLocation');
      expect(calls.single.arguments, isNull);
      expect(fix.latitudeE6, 7000000);
      expect(fix.longitudeE6, 125000000);
      expect(fix.accuracyM, 1500);
      expect(fix.capturedAtUtc, DateTime.parse(captured));
      expect(fix.capturedAtUtc.isUtc, isTrue);
    },
  );

  test(
    'a precise grant uses the same one-shot contract without requesting another fix',
    () async {
      reply['accuracyM'] = 3;
      final fix = await service.currentLocation();
      expect(fix.accuracyM, 3);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'currentLocation');
      expect(calls.single.arguments, isNull);
    },
  );

  for (final code in [
    'denied',
    'disabled',
    'timeout',
    'unavailable',
    'canceled',
    'busy',
  ]) {
    test(
      '$code becomes a recoverable manual-fallback message without platform details',
      () async {
        failure = PlatformException(
          code: code,
          message: 'PRIVATE_PLATFORM_DETAIL',
        );
        await expectLater(
          service.currentLocation(),
          throwsA(
            isA<LocationException>()
                .having((error) => error.code, 'code', code)
                .having(
                  (error) => error.message,
                  'safe fallback',
                  allOf(
                    contains('manual'),
                    isNot(contains('PRIVATE_PLATFORM_DETAIL')),
                  ),
                ),
          ),
        );
        expect(calls, hasLength(1));
      },
    );
  }

  test(
    'an unrecognized platform failure never exposes its message or starts a retry',
    () async {
      failure = PlatformException(
        code: 'vendor_error',
        message: 'PRIVATE_PLATFORM_DETAIL',
      );
      await expectLater(
        service.currentLocation(),
        throwsA(
          isA<LocationException>().having(
            (error) => error.code,
            'safe code',
            'unavailable',
          ),
        ),
      );
      expect(calls, hasLength(1));
    },
  );

  test(
    'a missing native implementation leaves manual fallback available',
    () async {
      messenger.setMockMethodCallHandler(LocationService.channel, null);
      await expectLater(
        service.currentLocation(),
        throwsA(
          isA<LocationException>().having(
            (error) => error.code,
            'safe code',
            'unavailable',
          ),
        ),
      );
    },
  );

  test('stale and far-future native fixes cannot be used', () async {
    for (final timestamp in [
      DateTime.now().toUtc().subtract(const Duration(minutes: 3)),
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    ]) {
      reply['capturedAtUtc'] = timestamp.toIso8601String();
      await expectLater(
        service.currentLocation(),
        throwsA(isA<LocationException>()),
      );
    }
  });

  test('invalid microdegrees, accuracy, or timestamp fail safely', () async {
    final original = {...reply};
    for (final bad in [
      {'latitudeE6': 90000001},
      {'latitudeE6': -90000001},
      {'longitudeE6': 180000001},
      {'longitudeE6': -180000001},
      {'latitudeE6': 7.0},
      {'accuracyM': 0},
      {'accuracyM': 100001},
      {'accuracyM': 1.5},
      {'capturedAtUtc': 'not a date'},
      {'capturedAtUtc': '2026-01-01T00:00:00+08:00'},
    ]) {
      reply = {...original, ...bad};
      await expectLater(
        service.currentLocation(),
        throwsA(isA<LocationException>()),
      );
    }
  });

  test(
    'a null native result is unavailable rather than a zero-coordinate fix',
    () async {
      messenger.setMockMethodCallHandler(
        LocationService.channel,
        (_) async => null,
      );
      await expectLater(
        service.currentLocation(),
        throwsA(isA<LocationException>()),
      );
    },
  );

  test('a malformed native payload remains a recoverable failure', () async {
    messenger.setMockMethodCallHandler(
      LocationService.channel,
      (_) async => <String, dynamic>{
        'latitudeE6': null,
        'longitudeE6': '125000000',
      },
    );
    await expectLater(
      service.currentLocation(),
      throwsA(
        isA<LocationException>().having(
          (error) => error.code,
          'safe code',
          'unavailable',
        ),
      ),
    );
  });
}
