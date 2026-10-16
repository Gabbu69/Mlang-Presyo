import '../app/english.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/controller.dart';
import '../app/strings.dart';
import '../core/domain.dart';
import '../core/models.dart';
import '../data/portability.dart';
import 'catalog.dart';
import 'common.dart';
import 'spending.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  Future<bool> _export(String kind) async {
    if (ref.read(appProvider.notifier).isDemo) return false;
    if (!await confirm(
      context,
      'Export private records?',
      AppStrings.exportWarning,
      action: 'Choose file destination',
    )) {
      return false;
    }
    final data = await ref.read(appProvider.notifier).repository.load();
    final String content;
    final String extension;
    if (kind == 'backup') {
      content = encodeBackup(data);
      extension = 'json';
    } else {
      content = kind == 'prices' ? pricesCsv(data) : purchasesCsv(data);
      extension = 'csv';
    }
    final destination = await FilePicker.saveFile(
      dialogTitle: 'Save Presyo M’lang $kind',
      fileName: 'presyo_mlang_${kind}_${dateText(manilaToday())}.$extension',
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    if (destination == null) return false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(English.exportSavedToYourChosenDestination),
        ),
      );
    }
    return true;
  }

  Future<void> _runExport(String kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _export(kind);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      await _cleanup();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanup() async {
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {
      /* System-selected external exports are never deleted. */
    }
  }

  Future<void> _restore() async {
    if (_busy || ref.read(appProvider.notifier).isDemo) return;
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a Presyo M’lang JSON backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      const cap = 10 * 1024 * 1024;
      final length = file.lengthSync() ?? await file.length();
      if (length != null && length > cap) {
        throw const ValidationException(
          'Backup files must be 10 MiB or smaller.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (bytes.length + chunk.length > cap) {
          throw const ValidationException(
            'Backup files must be 10 MiB or smaller.',
          );
        }
        bytes.add(chunk);
      }
      final restored = decodeBackup(utf8.decode(bytes.takeBytes()));
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text(English.replaceYourNotebook),
          content: SingleChildScrollView(
            child: Text(
              'The validated backup contains:\n${restored.products.length} products\n${restored.stores.length} stores\n${restored.prices.length} price records\n${restored.lists.length} lists\n${restored.items.length} list items\n${restored.purchases.length} purchases\n${restored.monthlyBudgets.length} monthly budgets\n\nAll current real records and settings will be replaced. Save a backup of your current notebook first if you want to keep it.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text(English.cancel),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(c, 'backup'),
              child: const Text(English.backUpCurrentFirst),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, 'replace'),
              child: const Text(English.replaceRecords),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'backup') {
        final saved = await _export('backup');
        if (!saved || !mounted) return;
        if (!await confirm(
          context,
          'Current backup saved',
          'Replace your notebook with the validated backup you selected?',
          action: 'Replace records',
        )) {
          return;
        }
      }
      if (!mounted) return;
      await change(
        context,
        ref,
        (repo) => repo.restore(restored),
        success: 'Backup restored. Your notebook was replaced.',
      );
    } catch (e) {
      if (mounted) {
        showError(
          context,
          e is FormatException
              ? const ValidationException(
                  'This is not a readable UTF-8 JSON backup. Your records were not replaced.',
                )
              : e,
        );
      }
    } finally {
      await _cleanup();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(appProvider.notifier);
    final demo = controller.isDemo;
    return AppPage(
      title: English.settings,
      child: PagePadding(
        children: [
          const Text(
            English.presyoMLang010,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const Text(English.internalDevelopmentBuildAndroidV1),
          const SectionTitle('Your notebook'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text(English.manageProducts),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CatalogPage(products: true),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_outlined),
            title: const Text(English.manageStores),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CatalogPage(products: false),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text(English.thisMonthSBudget),
            onTap: () => editMonthlyBudget(
              context,
              ref,
              dateText(manilaToday()).substring(0, 7),
            ),
          ),
          const SectionTitle('Backup and exports'),
          const Text(English.manualJsonBackupsCanBeRestoredCsvFilesAre),
          fieldGap(),
          if (demo)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  English.exportRestoreAndRealDataResetAreUnavailableIn,
                ),
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          ...[
            ('backup', 'Save JSON backup', Icons.save_outlined),
            ('prices', 'Export price records CSV', Icons.price_change_outlined),
            ('purchases', 'Export purchases CSV', Icons.receipt_long_outlined),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: demo || _busy ? null : () => _runExport(item.$1),
                icon: Icon(item.$3),
                label: Text(item.$2),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: demo || _busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Text(English.restoreJsonBackup),
          ),
          const SectionTitle('Practice mode'),
          const Text(English.demoRecordsAreFictionalAndKeptInASeparate),
          fieldGap(),
          FilledButton.tonalIcon(
            onPressed: _busy
                ? null
                : () async {
                    Navigator.popUntil(context, (r) => r.isFirst);
                    await controller.switchMode(!demo);
                  },
            icon: Icon(demo ? Icons.person_outline : Icons.science_outlined),
            label: Text(demo ? 'Return to my notebook' : 'Try isolated demo'),
          ),
          if (demo)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (await confirm(
                            context,
                            'Reset demo?',
                            'Only fictional demo records will be reset.',
                            action: 'Reset demo',
                          ) &&
                          context.mounted) {
                        await change(context, ref, (repo) async {
                          await repo.reset();
                          await repo.seedDemo();
                        });
                      }
                    },
              child: const Text(English.resetFictionalDemo),
            ),
          const SectionTitle('Privacy and local data'),
          const Text(AppStrings.privacy),
          fieldGap(),
          const Text(AppStrings.independent),
          fieldGap(),
          if (!demo)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      if (await confirm(
                            context,
                            'Delete all local records?',
                            'Your real in-app products, stores, prices, lists, purchases, budgets, and settings will be removed. Exports already saved or shared cannot be retracted. External files will not be deleted.',
                            action: 'Delete local records',
                          ) &&
                          context.mounted) {
                        setState(() => _busy = true);
                        final ok = await change(
                          context,
                          ref,
                          (repo) => repo.reset(),
                        );
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.popUntil(context, (r) => r.isFirst);
                        } else {
                          setState(() => _busy = false);
                        }
                      }
                    },
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text(English.deleteAllRealLocalRecords),
            ),
        ],
      ),
    );
  }
}
