import 'english.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/common.dart';
import '../features/home.dart';
import '../features/lists.dart';
import '../features/prices.dart';
import '../features/settings.dart';
import '../features/spending.dart';
import 'controller.dart';
import 'strings.dart';
import 'theme.dart';

class PresyoApp extends StatelessWidget {
  const PresyoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppStrings.title,
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: const AppShell(),
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;
  bool _starting = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    return state.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Opening your notebook',
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: SafeArea(
          child: PagePadding(
            children: [
              const SectionTitle('Could not open your notebook'),
              const Text(English.yourSavedRecordsHaveNotBeenDeletedPleaseRetry),
              fieldGap(),
              FilledButton(
                onPressed: () => ref.invalidate(appProvider),
                child: const Text(English.retry),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final demo = ref.read(appProvider.notifier).isDemo;
        if (data.settings['onboarded'] != true && !demo) {
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: MediaQuery.textScalerOf(
                context,
              ).scale(64).clamp(64.0, 128.0).toDouble(),
              title: const Text(AppStrings.title),
            ),
            body: SafeArea(
              child: PagePadding(
                children: [
                  const SizedBox(height: 24),
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SectionTitle('Your own shopping companion'),
                  const Text(AppStrings.tagline),
                  fieldGap(),
                  const Text(
                    English
                        .keepShoppingListsRecordComparablePricesAndTrackActual,
                  ),
                  fieldGap(),
                  const Text(
                    English.recordedPricesMayChangeYourRecordsStayPrivateUnless,
                  ),
                  fieldGap(),
                  FilledButton(
                    onPressed: _starting
                        ? null
                        : () async {
                            setState(() => _starting = true);
                            await change(
                              context,
                              ref,
                              (repo) => repo.setSetting('onboarded', true),
                            );
                            if (mounted) setState(() => _starting = false);
                          },
                    child: const Text(English.startEmpty),
                  ),
                  fieldGap(),
                  OutlinedButton(
                    onPressed: _starting
                        ? null
                        : () => ref.read(appProvider.notifier).switchMode(true),
                    child: const Text(English.tryFictionalDemo),
                  ),
                  const SizedBox(height: 24),
                  const Text(AppStrings.independent),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: MediaQuery.textScalerOf(
              context,
            ).scale(64).clamp(64.0, 128.0).toDouble(),
            title: const Text(AppStrings.title),
            actions: [
              IconButton(
                tooltip: English.settingsBackupAndPrivacy,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              const DemoBanner(),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: const [
                    HomePage(),
                    ListsPage(),
                    PricesPage(),
                    SpendingPage(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: 'Lists',
              ),
              NavigationDestination(
                icon: Icon(Icons.sell_outlined),
                selectedIcon: Icon(Icons.sell),
                label: 'Prices',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Spending',
              ),
            ],
          ),
        );
      },
    );
  }
}
