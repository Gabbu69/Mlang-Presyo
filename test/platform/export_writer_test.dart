import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Row;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/portability.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/features/settings.dart';
import 'package:presyo_mlang/platform/export_writer.dart';

import '../widgets/app_flow_test.dart' show mount, reveal, seed;

/// Settings intentionally animates its busy progress indicator while a modal
/// confirmation is open, so waiting for every scheduled frame to settle is
/// incorrect here. Wait for the relevant state, then finish the modal animation.
Future<void> pumpUntilState(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) {
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
  }
  expect(condition(), isTrue, reason: description);
}

final class MemoryPickedFile extends PlatformFile {
  MemoryPickedFile(this.bytes);
  final Uint8List bytes;

  @override
  String get name => 'fictional_backup.json';
  @override
  Uri get uri => Uri.parse('file:///fictional_backup.json');
  @override
  Never get xFile => throw UnsupportedError('This fixture uses byte streams.');
  @override
  int lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class PickerFixture extends FilePickerPlatform {
  PlatformFile? file;
  int cleanups = 0;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => file;

  @override
  Future<void> clearTemporaryFiles() async {
    cleanups++;
  }
}

class RestoreRecordingRepository extends AppRepository {
  RestoreRecordingRepository(super.db);
  int restoreCalls = 0;

  @override
  Future<void> restore(AppData data, {void Function()? beforeCommit}) async {
    restoreCalls++;
    await super.restore(data, beforeCommit: beforeCommit);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const writer = ExportWriter();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FilePickerPlatform previousPicker;
  late PickerFixture picker;
  late List<MethodCall> calls;
  Object? reply;
  PlatformException? failure;

  setUp(() {
    calls = [];
    reply = true;
    failure = null;
    previousPicker = FilePickerPlatform.instance;
    picker = PickerFixture();
    FilePickerPlatform.instance = picker;
    messenger.setMockMethodCallHandler(ExportWriter.channel, (call) async {
      calls.add(call);
      if (failure != null) throw failure!;
      return reply;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(ExportWriter.channel, null);
    FilePickerPlatform.instance = previousPicker;
  });

  test(
    'checked export sends exact UTF-8 bytes and confirms native success',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('Fictional ₱ export'));
      expect(
        await writer.save(
          fileName: 'fictional.json',
          mimeType: 'application/json',
          bytes: bytes,
        ),
        true,
      );
      expect(calls.single.method, 'saveExport');
      final arguments = calls.single.arguments as Map;
      expect(arguments['fileName'], 'fictional.json');
      expect(arguments['mimeType'], 'application/json');
      expect(arguments['bytes'], orderedEquals(bytes));
    },
  );

  test('native picker cancellation never confirms a backup', () async {
    reply = null;
    expect(
      await writer.save(
        fileName: 'fictional.json',
        mimeType: 'application/json',
        bytes: Uint8List(0),
      ),
      false,
    );
  });

  test(
    'native provider error is recoverable without exposing private details',
    () async {
      failure = PlatformException(
        code: 'export_write_failed',
        message: 'content://fictional/private/name',
      );
      await expectLater(
        writer.save(
          fileName: 'fictional.csv',
          mimeType: 'text/csv',
          bytes: Uint8List(1),
        ),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'safe message',
            allOf(
              contains('No backup was confirmed'),
              isNot(contains('content://')),
            ),
          ),
        ),
      );
    },
  );

  test('missing native export bridge never claims a saved backup', () async {
    messenger.setMockMethodCallHandler(ExportWriter.channel, null);
    await expectLater(
      writer.save(
        fileName: 'fictional.json',
        mimeType: 'application/json',
        bytes: Uint8List(1),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  for (final outcome in ['canceled', 'failed']) {
    testWidgets(
      'backup-first $outcome export preserves the real notebook and stops restore',
      (tester) async {
        final repository = RestoreRecordingRepository(AppDatabase.memory());
        addTearDown(repository.close);
        await seed(repository);
        final timestamp = DateTime.now().toUtc();
        final before = encodeBackup(await repository.load(), now: timestamp);
        picker.file = MemoryPickedFile(
          Uint8List.fromList(
            utf8.encode(encodeBackup(AppData.empty(), now: timestamp)),
          ),
        );
        if (outcome == 'canceled') {
          reply = null;
        } else {
          failure = PlatformException(
            code: 'export_write_failed',
            message: 'Fictional provider failure',
          );
        }
        await mount(
          tester,
          repository,
          form: const SettingsPage(),
          viewport: const Size(390, 844),
        );
        final restore = find.widgetWithText(
          OutlinedButton,
          'Restore JSON backup',
        );
        await reveal(tester, restore);
        await tester.tap(restore);
        await pumpUntilState(
          tester,
          () => find
              .text('Back up current first')
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          'The validated restore preview must be visible while Settings is busy.',
        );
        expect(find.text('Replace your notebook?'), findsOneWidget);
        await tester.tap(find.text('Back up current first'));
        await pumpUntilState(
          tester,
          () => find
              .text('Choose file destination')
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          'The private-export confirmation must be visible while Settings is busy.',
        );
        await tester.tap(find.text('Choose file destination'));
        await pumpUntilState(
          tester,
          () =>
              picker.cleanups == 1 &&
              find.byType(AlertDialog).evaluate().isEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
          'Canceled or failed export must finish cleanup and release the busy state.',
        );
        expect(calls, hasLength(1));
        expect(repository.restoreCalls, 0);
        expect(encodeBackup(await repository.load(), now: timestamp), before);
        expect(find.text('Current backup saved'), findsNothing);
        expect(
          find.text('Export saved to your chosen destination.'),
          findsNothing,
        );
        expect(picker.cleanups, 1);
        if (outcome == 'failed') {
          expect(
            find.textContaining('The export could not be saved.'),
            findsOneWidget,
          );
        }
        expect(tester.widget<OutlinedButton>(restore).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'canceling the restore preview never invokes export or replacement',
    (tester) async {
      final repository = RestoreRecordingRepository(AppDatabase.memory());
      addTearDown(repository.close);
      await seed(repository);
      final timestamp = DateTime.now().toUtc();
      final before = encodeBackup(await repository.load(), now: timestamp);
      picker.file = MemoryPickedFile(
        Uint8List.fromList(
          utf8.encode(encodeBackup(AppData.empty(), now: timestamp)),
        ),
      );
      await mount(
        tester,
        repository,
        form: const SettingsPage(),
        viewport: const Size(390, 844),
      );
      final restore = find.widgetWithText(
        OutlinedButton,
        'Restore JSON backup',
      );
      await reveal(tester, restore);
      await tester.tap(restore);
      await pumpUntilState(
        tester,
        () => find
            .text('Replace your notebook?')
            .hitTestable()
            .evaluate()
            .isNotEmpty,
        'The validated restore preview must be visible while Settings is busy.',
      );
      await tester.tap(find.text('Cancel'));
      await pumpUntilState(
        tester,
        () =>
            picker.cleanups == 1 &&
            find.byType(AlertDialog).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
        'Canceled restore must finish cleanup and release the busy state.',
      );
      expect(repository.restoreCalls, 0);
      expect(calls, isEmpty);
      expect(encodeBackup(await repository.load(), now: timestamp), before);
      expect(picker.cleanups, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
