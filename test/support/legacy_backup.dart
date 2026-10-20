import 'dart:convert';

import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/validation.dart';

/// Historical format-1 wire shape, including its original frozen snapshots.
Row legacyBackupDocument(AppData data, {required DateTime now}) {
  final document = jsonDecode(encodeBackup(data, now: now)) as Row;
  document['format_version'] = 1;
  for (final store in document['stores'] as List) {
    for (final field in storeLocationFields) {
      (store as Map).remove(field);
    }
  }
  for (final item in document['list_items'] as List) {
    final snapshot = item['estimate_basis_snapshot'] as Map?;
    for (final field in storeLocationFields) {
      snapshot?.remove('store_$field');
    }
  }
  for (final purchase in document['purchases'] as List) {
    final snapshot = purchase['store_snapshot'] as Map?;
    for (final field in storeLocationFields) {
      snapshot?.remove(field);
    }
  }
  for (final field in shoppingAreaSettings) {
    (document['app_settings'] as Map).remove(field);
  }
  return document;
}
