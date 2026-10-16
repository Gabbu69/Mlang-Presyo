import 'dart:convert';
import 'dart:io';

import 'package:presyo_mlang/data/database.dart';

Future<void> main(List<String> arguments) async {
  File? sqliteOutput;
  if (arguments.isNotEmpty) {
    if (arguments.length != 2 || arguments.first != '--sqlite-output') {
      stderr.writeln(
        'Usage: dart run tool/export_schema.dart '
        '[--sqlite-output NEW_SQLITE_FILE]',
      );
      exitCode = 64;
      return;
    }
    sqliteOutput = File(arguments[1]);
    if (await sqliteOutput.exists()) {
      throw StateError('Refusing to overwrite an existing SQLite file.');
    }
    await sqliteOutput.parent.create(recursive: true);
  }
  // A file source lets the documented drift_dev CLI introspect our actual SQL
  // schema without pretending allTables contains generated table definitions.
  final database = sqliteOutput == null
      ? AppDatabase.memory()
      : AppDatabase.file(sqliteOutput);
  try {
    final schema = await database.exportedSchema();
    if (sqliteOutput == null) {
      final target = File('drift_schemas/schema_v1.json');
      await target.parent.create(recursive: true);
      await target.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert({'schema_version': database.schemaVersion, 'source': 'sqlite_master from AppDatabase.memory()', 'entities': schema})}\n',
      );
      stdout.writeln(
        'Exported ${schema.length} schema entities to ${target.path}.',
      );
    }
  } finally {
    await database.close();
  }
  if (sqliteOutput != null) {
    stdout.writeln(
      'Created SQLite source at ${sqliteOutput.path}. '
      'Use drift_dev schema dump to create the official schema snapshot.',
    );
  }
}
