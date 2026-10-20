import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/models.dart' show AppData;
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/repository.dart';

import 'app_flow_test.dart' show mount, settle;

void main() {
  testWidgets('Home and Lists show the actual newest restored shopping list', (
    tester,
  ) async {
    final repository = AppRepository(AppDatabase.memory());
    addTearDown(repository.close);
    await repository.restore(
      AppData(
        lists: [
          {
            'id': '10000000-0000-4000-8000-000000000020',
            'title': 'Older restored list',
            'budget_centavos': null,
            'status': 'active',
            'created_at_utc': '2026-10-16T06:00:00Z',
            'updated_at_utc': '2026-10-16T06:00:00Z',
          },
          {
            'id': '10000000-0000-4000-8000-000000000021',
            'title': 'Newer restored list',
            'budget_centavos': null,
            'status': 'active',
            'created_at_utc': '2026-10-16T06:00:00Z',
            'updated_at_utc': '2026-10-16T06:00:00.500Z',
          },
        ],
        settings: {'onboarded': true},
      ),
    );
    await mount(tester, repository, viewport: const Size(390, 1000));
    expect(find.text('Newer restored list'), findsOneWidget);
    expect(find.text('Older restored list'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Lists'),
      ),
    );
    await settle(tester);
    expect(find.text('Newer restored list'), findsOneWidget);
    expect(find.text('Older restored list'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Newer restored list')).dy,
      lessThan(tester.getTopLeft(find.text('Older restored list')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
