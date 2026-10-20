import 'dart:io';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presyo_mlang/core/domain.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';

import '../data/repository_test.dart' show fixtures, now, purchase;
import '../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;
  late Directory directory;

  setUp(() async {
    verifier = SchemaVerifier(GeneratedHelper());
    directory = await Directory.systemTemp.createTemp('presyo_schema_test_');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'Drift snapshot verifies real initial creation and populated v2 reopen',
    () async {
      final file = File('${directory.path}/notebook.sqlite');
      var database = AppDatabase.file(file);
      var repository = AppRepository(database, clock: () => now);
      try {
        // This opens an empty file and invokes the real v2 onCreate. The
        // separate migration suite starts from the actual historical v1 schema.
        await verifier.migrateAndValidate(
          database,
          2,
          options: const ValidationOptions(validateDropped: true),
        );
        await fixtures(repository);
        await repository.savePurchase(purchase());
        final before = encodeBackup(await repository.load(), now: now);
        await repository.close();

        database = AppDatabase.file(file);
        repository = AppRepository(database, clock: () => now);
        await verifier.migrateAndValidate(
          database,
          2,
          options: const ValidationOptions(validateDropped: true),
        );
        final reopened = await repository.load();
        expect(encodeBackup(reopened, now: now), before);
        expect(monthlySpent(reopened, '2026-10'), 9000);
        expect(reopened.items.single['status'], 'bought');
        expect(
          await database.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await database.customSelect('PRAGMA foreign_keys').getSingle())
              .data
              .values
              .single,
          1,
        );
      } finally {
        await repository.close();
      }
    },
  );

  test(
    'Drift verifier detects unexpected tables in the initial schema',
    () async {
      final database = AppDatabase.file(File('${directory.path}/drift.sqlite'));
      try {
        await database.customStatement(
          'CREATE TABLE unexpected_test_table '
          '(id INTEGER PRIMARY KEY)',
        );
        await expectLater(
          verifier.migrateAndValidate(
            database,
            2,
            options: const ValidationOptions(validateDropped: true),
          ),
          throwsA(isA<SchemaMismatch>()),
        );
      } finally {
        await database.close();
      }
    },
  );
}
