import '../app/english.dart';

import 'package:flutter/material.dart' hide Row;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app/controller.dart';
import '../app/strings.dart';
import '../core/domain.dart';
import '../core/models.dart';
import '../data/repository.dart';

String productName(Row row) => [
  row['name'],
  row['brand'],
  row['variant_grade'],
].where((v) => v != null && v.toString().trim().isNotEmpty).join(' · ');
String sourceName(String source) => switch (source) {
  'purchase' => 'My purchase',
  'seller_quote' => 'Seller quote',
  _ => 'Personally observed',
};
String quantityOf(Row product, int quantity) =>
    quantityLabel(quantity, product['quantity_kind'] as String);
String nowUtc() => DateTime.now().toUtc().toIso8601String();
String newId() => const Uuid().v4();

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(English.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

void showError(BuildContext context, Object error) {
  final message = error is ValidationException
      ? error.message
      : 'Could not save or load your records. Your unsaved form is still here. Please retry. If storage is full, free space and try again.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 7)),
  );
}

Future<bool> change(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(AppRepository) action, {
  String? success,
}) async {
  try {
    await ref.read(appProvider.notifier).change(action);
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (error) {
    if (context.mounted) showError(context, error);
    return false;
  }
}

class DemoBanner extends ConsumerWidget {
  const DemoBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(appProvider.notifier).isDemo
      ? Container(
          width: double.infinity,
          color: const Color(0xFFFFE3B0),
          padding: const EdgeInsets.all(12),
          child: const Text(
            AppStrings.demo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF572900),
            ),
          ),
        )
      : const SizedBox.shrink();
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(
        context,
      ).scale(64).clamp(64.0, 128.0).toDouble(),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      actions: actions,
    ),
    body: Column(
      children: [
        const DemoBanner(),
        Expanded(child: child),
      ],
    ),
  );
}

class PagePadding extends StatelessWidget {
  const PagePadding({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    children: children,
  );
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 36),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

class AmountLine extends StatelessWidget {
  const AmountLine(this.label, this.value, {super.key, this.strong = false});
  final String label, value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 4,
      spacing: 16,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    ),
  );
}

class SaveBar extends StatelessWidget {
  const SaveBar({
    super.key,
    required this.busy,
    required this.onSave,
    this.label = 'Save',
  });
  final bool busy;
  final VoidCallback onSave;
  final String label;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : onSave,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(busy ? 'Saving…' : label),
        ),
      ),
    ),
  );
}

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Date observed',
  });
  final String value, label;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(value),
        firstDate: DateTime(1),
        lastDate: manilaToday(),
      );
      if (picked != null) onChanged(dateText(picked));
    },
    icon: const Icon(Icons.calendar_today_outlined),
    label: Text('$label: $value'),
  );
}

Widget fieldGap() => const SizedBox(height: 16);
