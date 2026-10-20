import 'package:flutter/services.dart';

class LocationFix {
  const LocationFix({
    required this.latitudeE6,
    required this.longitudeE6,
    required this.accuracyM,
    required this.capturedAtUtc,
  });

  final int latitudeE6;
  final int longitudeE6;
  final int accuracyM;
  final DateTime capturedAtUtc;
}

class LocationException implements Exception {
  const LocationException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// One explicitly requested foreground fix. This never starts itself and never
/// retries permission prompts, performs geocoding, or sends coordinates online.
class LocationService {
  const LocationService();

  static const channel = MethodChannel('app.presyomlang/location');

  Future<LocationFix> currentLocation() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>(
        'currentLocation',
      );
      if (data == null) throw _failure('unavailable');
      final latitude = data['latitudeE6'];
      final longitude = data['longitudeE6'];
      final accuracy = data['accuracyM'];
      final capturedText = data['capturedAtUtc'];
      final captured = capturedText is String && capturedText.endsWith('Z')
          ? DateTime.tryParse(capturedText)
          : null;
      if (latitude is! int ||
          latitude < -90000000 ||
          latitude > 90000000 ||
          longitude is! int ||
          longitude < -180000000 ||
          longitude > 180000000 ||
          accuracy is! int ||
          accuracy < 1 ||
          accuracy > 100000 ||
          captured == null ||
          !captured.isUtc) {
        throw _failure('unavailable');
      }
      final age = DateTime.now().toUtc().difference(captured).inMilliseconds;
      if (age < -5000 || age > 120000) throw _failure('unavailable');
      return LocationFix(
        latitudeE6: latitude,
        longitudeE6: longitude,
        accuracyM: accuracy,
        capturedAtUtc: captured,
      );
    } on PlatformException catch (error) {
      throw _failure(error.code);
    } on MissingPluginException {
      throw _failure('unavailable');
    } on FormatException {
      throw _failure('unavailable');
    } on TypeError {
      throw _failure('unavailable');
    }
  }

  static LocationException _failure(String code) => switch (code) {
    'denied' => const LocationException(
      'denied',
      'Location permission was not granted. You can enter the location manually.',
    ),
    'disabled' => const LocationException(
      'disabled',
      'Device location is turned off. You can enter the location manually.',
    ),
    'timeout' => const LocationException(
      'timeout',
      'A recent location was not found within 20 seconds. You can enter it manually.',
    ),
    'canceled' => const LocationException(
      'canceled',
      'Location capture was canceled. You can enter the location manually.',
    ),
    'busy' => const LocationException(
      'busy',
      'A location request is already open. Finish that request or enter the location manually.',
    ),
    _ => const LocationException(
      'unavailable',
      'Location is unavailable. You can enter the location manually.',
    ),
  };
}
