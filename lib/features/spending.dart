import '../app/english.dart';

import 'package:flutter/material.dart' hide Row;
import 'package:flutter/material.dart' as material show Row;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/controller.dart';
import '../core/domain.dart';
import '../core/models.dart';
import 'catalog.dart';
import 'common.dart';

class PurchaseForm extends ConsumerStatefulWidget {
  const PurchaseForm({super.key, this.existing, this.item});
  final Row? existing, item;
  @override
  ConsumerState<PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<PurchaseForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount, _quantity;
  late final String _id;
  String? _product, _store;
  late String _date;
  String _unit = 'g';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _id = widget.existing?['id'] as String? ?? newId();
    _product =
        widget.existing?['product_id'] as String? ??
        widget.item?['product_id'] as String?;
    _store = widget.existing?['store_id'] as String?;
    _date =
        widget.existing?['purchased_on'] as String? ?? dateText(manilaToday());
    _amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : moneyInput(widget.existing!['actual_total_centavos'] as int),
    );
    _quantity = TextEditingController(
      text:
          widget.existing?['actual_quantity_base']?.toString() ??
          widget.item?['requested_quantity_base']?.toString() ??
          '',
    );
    if (_product != null) _unit = baseUnit(_kind);
  }

  String get _kind => _product == null
      ? 'mass'
      : ref.read(appProvider).requireValue.product(_product!)['quantity_kind']
            as String;
  @override
  void dispose() {
    _amount.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await change(
      context,
      ref,
      (repo) => repo.savePurchase({
        ...?widget.existing,
        'id': _id,
        'list_item_id': widget.item?['id'] ?? widget.existing?['list_item_id'],
        'product_id': _product!,
        'store_id': _store == '' ? null : _store,
        'actual_quantity_base': parseQuantity(_quantity.text, _unit, _kind),
        'actual_total_centavos': parseMoney(_amount.text),
        'purchased_on': _date,
      }),
      success: 'Purchase recorded in actual spending.',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = switch (_kind) {
      'volume' => ['mL', 'L'],
      'count' => ['pcs'],
      _ => ['g', 'kg'],
    };
    final linked =
        widget.item != null || widget.existing?['list_item_id'] != null;
    return AppPage(
      title: widget.existing == null
          ? 'Record actual purchase'
          : 'Edit actual purchase',
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _form,
              child: PagePadding(
                children: [
                  const Text(
                    English.enterWhatYouActuallyBoughtAndPaidAnEstimate,
                  ),
                  fieldGap(),
                  CatalogPicker(
                    product: true,
                    value: _product,
                    enabled: !linked && widget.existing == null,
                    onChanged: (v) => setState(() {
                      _product = v;
                      _unit = baseUnit(_kind);
                      _quantity.clear();
                    }),
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: English.actualQuantityBought,
                    ),
                    validator: (v) {
                      try {
                        parseQuantity(v ?? '', _unit, _kind);
                        return null;
                      } catch (e) {
                        return e.toString();
                      }
                    },
                  ),
                  fieldGap(),
                  DropdownButtonFormField<String>(
                    itemHeight: null,
                    key: ValueKey(_unit),
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: English.unit),
                    items: units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: English.actualTotalPaidPhp,
                      prefixText: '₱ ',
                    ),
                    validator: (v) {
                      try {
                        parseMoney(v ?? '');
                        return null;
                      } catch (e) {
                        return e.toString();
                      }
                    },
                  ),
                  fieldGap(),
                  CatalogPicker(
                    product: false,
                    optional: true,
                    value: _store,
                    onChanged: (v) => setState(() => _store = v),
                  ),
                  fieldGap(),
                  DateField(
                    value: _date,
                    label: 'Purchase date',
                    onChanged: (v) => setState(() => _date = v),
                  ),
                  fieldGap(),
                  if (linked)
                    const Text(
                      English.savingUpdatesThisItemAndItsOneSpendingEntry,
                    ),
                ],
              ),
            ),
          ),
          SaveBar(
            busy: _busy,
            onSave: _save,
            label: widget.existing == null
                ? 'Save actual purchase'
                : 'Save purchase changes',
          ),
        ],
      ),
    );
  }
}

Future<void> editMonthlyBudget(
  BuildContext context,
  WidgetRef ref,
  String month,
) async {
  final data = ref.read(appProvider).requireValue;
  await showDialog<void>(
    context: context,
    builder: (_) => _MonthlyBudgetDialog(
      month: month,
      initialCentavos: data.monthlyBudgets[month],
    ),
  );
}

class _MonthlyBudgetDialog extends ConsumerStatefulWidget {
  const _MonthlyBudgetDialog({required this.month, this.initialCentavos});
  final String month;
  final int? initialCentavos;

  @override
  ConsumerState<_MonthlyBudgetDialog> createState() =>
      _MonthlyBudgetDialogState();
}

class _MonthlyBudgetDialogState extends ConsumerState<_MonthlyBudgetDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.initialCentavos == null
          ? ''
          : moneyInput(widget.initialCentavos!),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final input = _amount.text.trim();
    final ok = await change(
      context,
      ref,
      (repo) => repo.setMonthlyBudget(
        widget.month,
        input.isEmpty ? null : parseMoney(input, max: 1000000000),
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Budget for ${widget.month}'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: English.monthlyBudgetPhp,
                  prefixText: '₱ ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  try {
                    parseMoney(v, max: 1000000000);
                    return null;
                  } catch (e) {
                    return e.toString();
                  }
                },
              ),
              fieldGap(),
              const Text(English.blankRemovesThisBudgetZeroIsASavedBudget),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text(English.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : English.save),
        ),
      ],
    ),
  );
}

class SpendingPage extends ConsumerStatefulWidget {
  const SpendingPage({super.key});
  @override
  ConsumerState<SpendingPage> createState() => _SpendingPageState();
}

class _SpendingPageState extends ConsumerState<SpendingPage> {
  late DateTime _selected;
  @override
  void initState() {
    super.initState();
    final today = manilaToday();
    _selected = DateTime.utc(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider).requireValue;
    final month = dateText(_selected).substring(0, 7);
    final purchases =
        data.purchases
            .where((p) => (p['purchased_on'] as String).startsWith(month))
            .toList()
          ..sort(
            (a, b) => (b['purchased_on'] as String).compareTo(
              a['purchased_on'] as String,
            ),
          );
    final actual = monthlySpent(data, month);
    final budget = data.monthlyBudgets[month];
    final categories = categoryTotals(data, month);
    return PagePadding(
      children: [
        Text(
          English.actualGrocerySpending,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(English.onlyPurchasesYouRecordedAppearHere),
        material.Row(
          children: [
            IconButton(
              tooltip: English.previousMonth,
              onPressed: () => setState(
                () => _selected = DateTime.utc(
                  _selected.year,
                  _selected.month - 1,
                ),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                month,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: English.nextMonth,
              onPressed: () => setState(
                () => _selected = DateTime.utc(
                  _selected.year,
                  _selected.month + 1,
                ),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(actual),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${purchases.length} recorded purchase${purchases.length == 1 ? '' : 's'}',
                ),
                if (budget != null) ...[
                  AmountLine('Monthly budget', money(budget)),
                  AmountLine('Balance after purchases', money(budget - actual)),
                ],
                TextButton.icon(
                  onPressed: () => editMonthlyBudget(context, ref, month),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    budget == null
                        ? 'Set monthly budget'
                        : 'Edit monthly budget',
                  ),
                ),
              ],
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PurchaseForm()),
          ),
          icon: const Icon(Icons.add),
          label: const Text(English.addPurchase),
        ),
        if (categories.isNotEmpty) ...[
          const SectionTitle('By category'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: categories.entries
                    .map((e) => AmountLine(e.key, money(e.value)))
                    .toList(),
              ),
            ),
          ),
        ],
        const SectionTitle('Purchase ledger'),
        if (purchases.isEmpty)
          const EmptyCard(
            icon: Icons.receipt_long_outlined,
            title: English.noPurchasesThisMonth,
            message: English.recordingAPriceDoesNotAddAnExpenseAdd,
          ),
        ...purchases.map((p) {
          final snapshot = Map<String, dynamic>.from(
            p['product_snapshot'] as Map,
          );
          final store = p['store_snapshot'] as Map?;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName(snapshot),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${money(p['actual_total_centavos'] as int)} · ${quantityLabel(p['actual_quantity_base'] as int, snapshot['quantity_kind'] as String)}',
                  ),
                  Text(
                    '${p['purchased_on']} · ${store?['name'] ?? 'Store not specified'}',
                  ),
                  Text(snapshot['category'] as String),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PurchaseForm(existing: p),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text(English.editPurchase),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          if (await confirm(
                                context,
                                'Delete purchase?',
                                p['list_item_id'] == null
                                    ? 'This actual spending entry will be removed.'
                                    : 'This spending entry will be removed and the linked list item will be needed again.',
                                action: 'Delete purchase',
                              ) &&
                              context.mounted) {
                            await change(
                              context,
                              ref,
                              (repo) => repo.deletePurchase(p['id'] as String),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text(English.delete),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
