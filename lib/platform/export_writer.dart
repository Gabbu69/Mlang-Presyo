import 'package:flutter/services.dart';

import '../core/models.dart';

/// The Android bridge confirms success only after the chosen document stream
/// has been written, flushed, and closed. A canceled picker returns null.
class ExportWriter {
  const ExportWriter();

  static const channel = MethodChannel('app.presyomlang/export_writer');

  Future<bool> save({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    try {
      final saved = await channel.invokeMethod<bool>('saveExport', {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      });
      return saved == true;
    } on PlatformException {
      // Provider paths and exception details may contain private information.
      throw const ValidationException(
        'The export could not be saved. No backup was confirmed. Your notebook has not been replaced. Choose another destination and try again.',
      );
    } on MissingPluginException {
      throw const ValidationException(
        'Export is unavailable in this installation. No backup was confirmed and your notebook has not been replaced.',
      );
    }
  }
}
