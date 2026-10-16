import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/models.dart';
import '../data/database.dart';
import '../data/repository.dart';

final appProvider = AsyncNotifierProvider<AppController, AppData>(
  AppController.new,
);

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
    state = await AsyncValue.guard(() => repository.load());
  }

  Future<void> change(Future<void> Function(AppRepository) action) async {
    await action(repository);
    state = AsyncData(await repository.load());
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
