import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presyo_mlang/app/app.dart';
import 'package:presyo_mlang/app/controller.dart';
import 'package:presyo_mlang/app/strings.dart';
import 'package:presyo_mlang/core/models.dart';
import 'package:presyo_mlang/data/database.dart';
import 'package:presyo_mlang/data/repository.dart';
import 'package:presyo_mlang/features/common.dart';

const sourceListId = '70000000-0000-4000-8000-000000000001';

class ReadFailureRepository extends AppRepository {
  ReadFailureRepository(super.db);

  int failedReadsRemaining = 0;
  int duplicateCalls = 0;

  @override
  Future<AppData> load() async {
    if (failedReadsRemaining > 0) {
      failedReadsRemaining--;
      throw StateError('Injected read failure after a committed write.');
    }
    return super.load();
  }

  @override
  Future<String> duplicateList(String listId) async {
    duplicateCalls++;
    final result = await super.duplicateList(listId);
    failedReadsRemaining = 1;
    return result;
  }
}

class TestReadController extends AppController {
  TestReadController(this.testRepository);

  final AppRepository testRepository;

  @override
  AppRepository get repository => testRepository;

  @override
  Future<AppData> build() => repository.load();
}

void main() {
  late ReadFailureRepository repository;
  late ProviderContainer container;

  setUp(() async {
    repository = ReadFailureRepository(AppDatabase.memory());
    await repository.setSetting('onboarded', true);
    await repository.saveList({'id': sourceListId, 'title': 'Original list'});
    container = ProviderContainer(
      overrides: [
        appProvider.overrideWith(() => TestReadController(repository)),
      ],
    );
    await container.read(appProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await repository.close();
  });

  test(
    'a committed duplicate is not replayed after its refresh fails',
    () async {
      final controller = container.read(appProvider.notifier);
      final refreshed = await controller.change((repo) async {
        await repo.duplicateList(sourceListId);
      });

      expect(refreshed, isFalse);
      expect(container.read(notebookReloadNeededProvider), isTrue);
      expect(container.read(appProvider).requireValue.lists, hasLength(1));
      expect((await repository.load()).lists, hasLength(2));
      expect(repository.duplicateCalls, 1);

      var replayedActions = 0;
      expect(
        await controller.change((repo) async {
          replayedActions++;
          await repo.duplicateList(sourceListId);
        }),
        isFalse,
      );
      expect(replayedActions, 0);

      repository.failedReadsRemaining = 1;
      await controller.refresh();
      expect(container.read(notebookReloadNeededProvider), isTrue);
      await controller.refresh();
      expect(container.read(notebookReloadNeededProvider), isFalse);
      expect(container.read(appProvider).requireValue.lists, hasLength(2));
      expect(repository.duplicateCalls, 1);
    },
  );

  test(
    'an uncommitted write failure keeps its previous state and throws',
    () async {
      final before = container.read(appProvider).requireValue;
      await expectLater(
        container.read(appProvider.notifier).change((repo) async {
          throw StateError('Injected failure before mutation.');
        }),
        throwsStateError,
      );
      expect(container.read(appProvider).requireValue, same(before));
      expect(container.read(notebookReloadNeededProvider), isFalse);
      expect((await repository.load()).lists, hasLength(1));
    },
  );

  testWidgets(
    'saved-refresh recovery retries reads without repeating the action',
    (tester) async {
      final refreshed = await container.read(appProvider.notifier).change((
        repo,
      ) async {
        await repo.duplicateList(sourceListId);
      });
      expect(refreshed, isFalse);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PresyoApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.savedRefreshTitle), findsOneWidget);
      expect(find.text(AppStrings.savedRefreshMessage), findsOneWidget);
      expect(find.text('Original list (copy)'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.savedRefreshTitle), findsNothing);
      expect(find.text('Original list (copy)'), findsOneWidget);
      expect(repository.duplicateCalls, 1);
    },
  );

  testWidgets('a failed post-commit refresh closes a stale detail route safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              if (ref.watch(notebookReloadNeededProvider)) {
                return const Scaffold(body: Text('Reload saved records'));
              }
              return Scaffold(
                body: FilledButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Consumer(
                        builder: (context, ref, _) => Scaffold(
                          body: FilledButton(
                            onPressed: () => change(context, ref, (repo) async {
                              await repo.duplicateList(sourceListId);
                            }),
                            child: Text(
                              'Duplicate ${ref.watch(appProvider).requireValue.lists.length}',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open detail'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate 1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Reload saved records'), findsOneWidget);
    expect(find.text('Duplicate 1'), findsNothing);
    expect(repository.duplicateCalls, 1);
    expect((await repository.load()).lists, hasLength(2));
  });

  testWidgets('demo refresh recovery retains the fictional-data banner', (
    tester,
  ) async {
    final controller = container.read(appProvider.notifier)..isDemo = true;
    expect(
      await controller.change((repo) async {
        await repo.duplicateList(sourceListId);
      }),
      isFalse,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const PresyoApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.savedRefreshTitle), findsOneWidget);
    expect(find.text(AppStrings.demo), findsOneWidget);
  });
}
