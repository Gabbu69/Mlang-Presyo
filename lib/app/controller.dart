import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/models.dart';
import '../data/database.dart';
import '../data/repository.dart';

final appProvider = AsyncNotifierProvider<AppController, AppData>(
  AppController.new,
);

/// A committed write must never be retried just because its follow-up read failed.
final notebookReloadNeededProvider =
    NotifierProvider<NotebookReloadStatus, bool>(NotebookReloadStatus.new);

class NotebookReloadStatus extends Notifier<bool> {
  @override
  bool build() => false;

  void markNeeded() => state = true;
  void clear() => state = false;
}

class AppController extends AsyncNotifier<AppData> {
  AppRepository? _repository;
  Directory? _directory;
  bool isDemo = false;
  bool _switching = false;

  AppRepository get repository => _repository!;

  @override
  Future<AppData> build() async {
    _directory = await getApplicationSupportDirectory();
    final mode = File('${_directory!.path}/mode.txt');
    isDemo = await mode.exists() && await mode.readAsString() == 'demo';
    ref.onDispose(() {
      _repository?.close();
    });
    return _open();
  }

  Future<AppData> _open() async {
    _repository = AppRepository(
      AppDatabase.file(
        File('${_directory!.path}/${isDemo ? 'demo' : 'personal'}.sqlite'),
      ),
      demo: isDemo,
    );
    if (isDemo) await repository.seedDemo();
    return repository.load();
  }

  Future<void> refresh() async {
    await _reload(repository);
  }

  /// False means the write committed, but the shell must reload before editing.
  Future<bool> change(Future<void> Function(AppRepository) action) async {
    if (ref.read(notebookReloadNeededProvider)) return false;
    final activeRepository = repository;
    await action(activeRepository);
    if (!ref.mounted) return false;
    return _reload(activeRepository, afterCommittedWrite: true);
  }

  Future<bool> _reload(
    AppRepository activeRepository, {
    bool afterCommittedWrite = false,
  }) async {
    final loaded = await AsyncValue.guard(activeRepository.load);
    if (!ref.mounted || !identical(repository, activeRepository)) return false;
    final reloadStatus = ref.read(notebookReloadNeededProvider.notifier);
    if (loaded.hasError) {
      if (afterCommittedWrite || ref.read(notebookReloadNeededProvider)) {
        // Keep the last snapshot usable while existing routes return to the
        // recovery screen. Further writes are blocked until a read succeeds.
        reloadStatus.markNeeded();
      } else {
        state = loaded;
      }
      return false;
    }
    state = loaded;
    reloadStatus.clear();
    return true;
  }

  Future<void> switchMode(bool demo) async {
    if (demo == isDemo || _switching) return;
    _switching = true;
    state = const AsyncLoading();
    try {
      state = await AsyncValue.guard(() async {
        await _repository?.close();
        isDemo = demo;
        await File(
          '${_directory!.path}/mode.txt',
        ).writeAsString(demo ? 'demo' : 'real', flush: true);
        return _open();
      });
    } finally {
      _switching = false;
    }
  }
}
