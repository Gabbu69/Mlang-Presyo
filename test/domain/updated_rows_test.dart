import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/core/models.dart';

void main() {
  test(
    'latest rows compare timestamp instants with mixed fractional precision',
    () {
      final rows = <Row>[
        {'id': 'older', 'updated_at_utc': '2026-10-16T06:00:00Z'},
        {'id': 'newer', 'updated_at_utc': '2026-10-16T06:00:00.500Z'},
        {'id': 'newest', 'updated_at_utc': '2026-10-16T06:00:00.500001Z'},
      ]..sort(compareUpdatedRows);
      expect(rows.map((row) => row['id']), ['newest', 'newer', 'older']);
    },
  );

  test(
    'equal update instants use stable IDs regardless of decimal spelling',
    () {
      final rows = <Row>[
        {'id': 'b', 'updated_at_utc': '2026-10-16T06:00:00.500000Z'},
        {'id': 'a', 'updated_at_utc': '2026-10-16T06:00:00.5Z'},
      ]..sort(compareUpdatedRows);
      expect(rows.map((row) => row['id']), ['a', 'b']);
    },
  );
}
