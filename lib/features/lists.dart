import '../app/english.dart';

import 'package:flutter/material.dart' hide Row;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/controller.dart';
import '../core/domain.dart';
import '../core/models.dart';
import 'catalog.dart';
import 'common.dart';
import 'spending.dart';

Future<void> chooseListForPrice(
  BuildContext context,
  WidgetRef ref,
  Row product,
  Row price,
) async {
  final lists = ref
      .read(appProvider)
      .requireValue
      .lists
      .where((l) => l['status'] == 'active')
      .toList();
  String? listId;
  if (lists.isEmpty) {
    listId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ListForm()),
    );
  } else {
    listId = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text(English.chooseAShoppingList),
        children: lists
            .map(
              (l) => SimpleDialogOption(
                onPressed: () => Navigator.pop(c, l['id']),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l['title'] as String),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
  if (listId != null && context.mounted) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemForm(
          listId: listId!,
          productId: product['id'] as String,
          selectedPrice: price,
        ),
      ),
    );
  }
}

class ListForm extends ConsumerStatefulWidget {
  const ListForm({super.key, this.existing});
  final Row? existing;
  @override
  ConsumerState<ListForm> createState() => _ListFormState();
}

class _ListFormState extends ConsumerState<ListForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _budget;
  late final String _id;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _id = widget.existing?['id'] as String? ?? newId();
    _title = TextEditingController(
      text: widget.existing?['title'] as String? ?? '',
    );
    _budget = TextEditingController(
      text: widget.existing?['budget_centavos'] == null
          ? ''
          : moneyInput(widget.existing!['budget_centavos'] as int),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await change(
      context,
      ref,
      (repo) => repo.saveList({
        ...?widget.existing,
        'id': _id,
        'title': _title.text.trim(),
        'budget_centavos': _budget.text.trim().isEmpty
            ? null
            : parseMoney(_budget.text, max: 1000000000),
        'status': widget.existing?['status'] ?? 'active',
      }),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, _id);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: widget.existing == null ? 'Create shopping list' : 'Edit list',
    child: Column(
      children: [
        Expanded(
          child: Form(
            key: _form,
            child: PagePadding(
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: English.listName,
                    hintText: English.weekendGroceries,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a list name.'
                      : null,
                ),
                fieldGap(),
                TextFormField(
                  controller: _budget,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: English.listBudgetOptional,
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
                const Text(English.leaveBudgetBlankForNoBudgetASavedZero),
              ],
            ),
          ),
        ),
        SaveBar(busy: _busy, onSave: _save),
      ],
    ),
  );
}

class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider).requireValue;
    final lists = [...data.lists]
      ..sort(
        (a, b) => (b['updated_at_utc'] as String).compareTo(
          a['updated_at_utc'] as String,
        ),
      );
    return PagePadding(
      children: [
        Text(
          English.planYourNextTrip,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(English.keepYourEstimatesSeparateFromWhatYouActuallyPay),
        fieldGap(),
        FilledButton.icon(
          onPressed: () async {
            final id = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const ListForm()),
            );
            if (id != null && context.mounted) {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => ListDetail(listId: id)),
              );
            }
          },
          icon: const Icon(Icons.add),
          label: const Text(English.createList),
        ),
        fieldGap(),
        if (lists.isEmpty)
          const EmptyCard(
            icon: Icons.shopping_bag_outlined,
            title: English.aLittlePlanningGoesALongWay,
            message: English.startAListAddWhatYouNeedAndChoose,
          ),
        for (final status in ['active', 'archived']) ...[
          if (lists.any((l) => l['status'] == status))
            SectionTitle(
              status == 'active' ? 'Active lists' : 'Archived lists',
            ),
          ...lists.where((l) => l['status'] == status).map((list) {
            final totals = listTotals(data, list['id'] as String);
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ListDetail(listId: list['id'] as String),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${data.listItems(list['id'] as String).where((i) => i['status'] == 'needed').length} items still needed',
                      ),
                      AmountLine('Actually spent', money(totals.actualSpent)),
                      AmountLine(
                        totals.missingEstimates > 0
                            ? 'Known projected subtotal'
                            : 'Projected total',
                        money(totals.projectedTotal),
                      ),
                      if (totals.missingEstimates > 0)
                        Text(
                          '${totals.missingEstimates} items need an estimate',
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class ListSummary extends StatelessWidget {
  const ListSummary({super.key, required this.data, required this.listId});
  final AppData data;
  final String listId;
  @override
  Widget build(BuildContext context) {
    final t = listTotals(data, listId);
    final list = data.lists.firstWhere((l) => l['id'] == listId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (list['budget_centavos'] != null)
              AmountLine('List budget', money(list['budget_centavos'] as int)),
            AmountLine('Actually spent', money(t.actualSpent)),
            if (t.budgetLeft != null)
              AmountLine('Budget left after purchases', money(t.budgetLeft!)),
            AmountLine('Estimated remaining cost', money(t.remainingEstimate)),
            const Divider(),
            AmountLine(
              t.missingEstimates > 0
                  ? 'Known projected subtotal'
                  : 'Projected total',
              money(t.projectedTotal),
              strong: true,
            ),
            if (t.missingEstimates > 0)
              Text(
                '${t.missingEstimates} needed item${t.missingEstimates == 1 ? '' : 's'} still need an estimate. Your full cost is not known.',
              )
            else if (t.projectedBalance != null)
              AmountLine('Projected balance', money(t.projectedBalance!)),
          ],
        ),
      ),
    );
  }
}

class ListDetail extends ConsumerStatefulWidget {
  const ListDetail({super.key, required this.listId});
  final String listId;
  @override
  ConsumerState<ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends ConsumerState<ListDetail> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider).requireValue;
    final found = data.lists.where((l) => l['id'] == widget.listId);
    if (found.isEmpty) {
      return const AppPage(
        title: English.list,
        child: Center(child: Text(English.thisListIsNoLongerInTheNotebook)),
      );
    }
    final list = found.first;
    final items = data.listItems(widget.listId);
    return AppPage(
      title: list['title'] as String,
      actions: [
        IconButton(
          tooltip: English.editListAndBudget,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<String>(builder: (_) => ListForm(existing: list)),
          ),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      child: PagePadding(
        children: [
          ListSummary(data: data, listId: widget.listId),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: list['status'] == 'archived'
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ItemForm(listId: widget.listId),
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: const Text(English.addItem),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        String? id;
                        final ok = await change(context, ref, (repo) async {
                          id = await repo.duplicateList(widget.listId);
                        });
                        if (!mounted) return;
                        setState(() => _busy = false);
                        if (ok && context.mounted) {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListDetail(listId: id!),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_outlined),
                label: const Text(English.duplicate),
              ),
              TextButton(
                onPressed: () => change(
                  context,
                  ref,
                  (repo) => repo.saveList({
                    ...list,
                    'status': list['status'] == 'archived'
                        ? 'active'
                        : 'archived',
                  }),
                ),
                child: Text(
                  list['status'] == 'archived' ? 'Make active' : 'Archive list',
                ),
              ),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: EmptyCard(
                icon: Icons.checklist,
                title: English.whatDoYouNeed,
                message: English.addAProductAndQuantityYouCanEstimateIt,
              ),
            ),
          for (final status in ['needed', 'bought', 'skipped']) ...[
            if (items.any((i) => i['status'] == status))
              SectionTitle(
                status == 'needed'
                    ? 'Still needed'
                    : status == 'bought'
                    ? 'Bought'
                    : 'Skipped',
              ),
            ...items.where((i) => i['status'] == status).map((item) {
              final product = data.product(item['product_id'] as String);
              final purchase = data.purchaseFor(item['id'] as String);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName(product),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Planned: ${quantityOf(product, item['requested_quantity_base'] as int)}',
                      ),
                      if (purchase != null) ...[
                        Text(
                          'Actually bought: ${quantityOf(product, purchase['actual_quantity_base'] as int)}',
                        ),
                        Text(
                          'Paid ${money(purchase['actual_total_centavos'] as int)} · ${purchase['purchased_on']}',
                        ),
                      ] else
                        Text(
                          item['estimate_total_centavos'] == null
                              ? 'Not estimated'
                              : 'Estimated ${money(item['estimate_total_centavos'] as int)}',
                        ),
                      if (item['estimate_basis_snapshot'] != null)
                        Text(
                          'Price basis observed ${(item['estimate_basis_snapshot'] as Map)['observed_on']} · frozen estimate',
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (status == 'needed')
                            FilledButton.tonalIcon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => PurchaseForm(item: item),
                                ),
                              ),
                              icon: const Icon(Icons.check),
                              label: const Text(English.recordBought),
                            ),
                          if (status != 'bought')
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => ItemForm(
                                    listId: widget.listId,
                                    existing: item,
                                  ),
                                ),
                              ),
                              child: const Text(English.editEstimate),
                            ),
                          if (status != 'bought')
                            TextButton(
                              onPressed: () => change(
                                context,
                                ref,
                                (repo) => repo.saveItem({
                                  ...item,
                                  'status': status == 'skipped'
                                      ? 'needed'
                                      : 'skipped',
                                }),
                              ),
                              child: Text(
                                status == 'skipped' ? 'Still needed' : 'Skip',
                              ),
                            ),
                          if (purchase != null)
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => PurchaseForm(
                                    existing: purchase,
                                    item: item,
                                  ),
                                ),
                              ),
                              child: const Text(English.editPurchase),
                            ),
                          if (purchase != null)
                            TextButton(
                              onPressed: () async {
                                if (await confirm(
                                      context,
                                      'Undo this purchase?',
                                      'The spending entry will be removed and this item will be needed again.',
                                      action: 'Undo purchase',
                                    ) &&
                                    context.mounted) {
                                  await change(
                                    context,
                                    ref,
                                    (repo) => repo.deletePurchase(
                                      purchase['id'] as String,
                                    ),
                                  );
                                }
                              },
                              child: const Text(English.undoPurchase),
                            ),
                          if (status != 'bought')
                            TextButton(
                              onPressed: () async {
                                if (await confirm(
                                      context,
                                      'Remove item?',
                                      'Remove this item from the shopping list?',
                                      action: 'Remove',
                                    ) &&
                                    context.mounted) {
                                  await change(
                                    context,
                                    ref,
                                    (repo) =>
                                        repo.deleteItem(item['id'] as String),
                                  );
                                }
                              },
                              child: const Text(English.remove),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class ItemForm extends ConsumerStatefulWidget {
  const ItemForm({
    super.key,
    required this.listId,
    this.existing,
    this.productId,
    this.selectedPrice,
  });
  final String listId;
  final Row? existing, selectedPrice;
  final String? productId;
  @override
  ConsumerState<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<ItemForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _quantity, _manual;
  late final String _id;
  String? _product, _sourceId;
  String _unit = 'g', _mode = 'none';
  Row? _basis;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    _id = row?['id'] as String? ?? newId();
    _product = row?['product_id'] as String? ?? widget.productId;
    _quantity = TextEditingController(
      text: row?['requested_quantity_base']?.toString() ?? '',
    );
    _manual = TextEditingController(
      text:
          row?['estimate_mode'] == 'manual' &&
              row?['estimate_total_centavos'] != null
          ? moneyInput(row!['estimate_total_centavos'] as int)
          : '',
    );
    _mode = row?['estimate_mode'] as String? ?? 'none';
    _sourceId = row?['source_price_id'] as String?;
    if (row?['estimate_basis_snapshot'] is Map) {
      _basis = Map<String, dynamic>.from(
        row!['estimate_basis_snapshot'] as Map,
      );
    }
    if (_product != null) _unit = baseUnit(_kind);
    if (widget.selectedPrice != null) {
      final data = ref.read(appProvider).requireValue;
      _mode = 'price';
      _sourceId = widget.selectedPrice!['id'] as String;
      _basis = priceSnapshot(
        widget.selectedPrice!,
        data.product(_product!),
        data.store(widget.selectedPrice!['store_id'] as String)!,
      );
    }
  }

  String get _kind => _product == null
      ? 'mass'
      : ref.read(appProvider).requireValue.product(_product!)['quantity_kind']
            as String;
  @override
  void dispose() {
    _quantity.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _quantityChanged(String value) {
    if (_mode == 'manual') _manual.clear();
    setState(() {});
  }

  Future<void> _choosePrice() async {
    if (_product == null) {
      showError(context, ValidationException('Choose a product first.'));
      return;
    }
    final data = ref.read(appProvider).requireValue;
    var older = false;
    final row = await showDialog<Row>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, updateDialog) {
          final choices = comparablePrices(
            data.prices,
            _product!,
            older: older,
          );
          return AlertDialog(
            title: const Text(English.chooseARecordedOffer),
            content: SizedBox(
              width: 480,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(c).height * .55,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(English.showOlderRecords),
                      subtitle: const Text(
                        English.datesRemainVisibleOlderPricesMayHaveChanged,
                      ),
                      value: older,
                      onChanged: (value) => updateDialog(() => older = value),
                    ),
                    if (choices.isEmpty)
                      Text(
                        older
                            ? English.noRegularRecordedOffersRecordAPriceFirstOr
                            : English.noRecentComparableRecords,
                      ),
                    ...choices.map(
                      (p) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        title: Text(
                          '${money(p['quoted_centavos'] as int)} / ${quantityLabel(p['offered_quantity_base'] as int, _kind)}',
                        ),
                        subtitle: Text(
                          '${data.store(p['store_id'] as String)!['name']} · ${p['selling_mode']}\n${p['observed_on']} · ${ageLabel(p['observed_on'] as String)}',
                        ),
                        onTap: () => Navigator.pop(c, p),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text(English.cancel),
              ),
            ],
          );
        },
      ),
    );
    if (row != null && mounted) {
      setState(() {
        _sourceId = row['id'] as String;
        _basis = priceSnapshot(
          row,
          data.product(_product!),
          data.store(row['store_id'] as String)!,
        );
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_mode == 'price' && _basis == null) {
      showError(
        context,
        ValidationException('Choose a recorded price for the estimate.'),
      );
      return;
    }
    setState(() => _busy = true);
    final requested = parseQuantity(_quantity.text, _unit, _kind);
    final total = _mode == 'none'
        ? null
        : _mode == 'manual'
        ? parseMoney(_manual.text)
        : estimatePrice(_basis!, requested).totalCentavos;
    final ok = await change(
      context,
      ref,
      (repo) => repo.saveItem(
        {
          ...?widget.existing,
          'id': _id,
          'list_id': widget.listId,
          'product_id': _product!,
          'requested_quantity_base': requested,
          'estimate_mode': _mode,
          'estimate_total_centavos': total,
          'source_price_id': _mode == 'price' ? _sourceId : null,
          'estimate_basis_snapshot': _mode == 'price' ? _basis : null,
          'status': widget.existing?['status'] ?? 'needed',
          'display_order':
              widget.existing?['display_order'] ??
              ref
                  .read(appProvider)
                  .requireValue
                  .listItems(widget.listId)
                  .length,
        },
        confirmManualEstimate:
            _mode == 'manual' && _manual.text.trim().isNotEmpty,
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
  Widget build(BuildContext context) {
    final units = switch (_kind) {
      'volume' => ['mL', 'L'],
      'count' => ['pcs'],
      _ => ['g', 'kg'],
    };
    String? preview;
    try {
      if (_mode == 'price' && _basis != null && _quantity.text.isNotEmpty) {
        final estimate = estimatePrice(
          _basis!,
          parseQuantity(_quantity.text, _unit, _kind),
        );
        preview =
            'Estimated ${money(estimate.totalCentavos)}${estimate.packages != null ? ' · ${estimate.packages} whole packs' : ''}${estimate.extraQuantity > 0 ? '\nExtra: ${quantityLabel(estimate.extraQuantity, _kind)}' : ''}';
      }
    } catch (_) {
      /* Input validation provides the actionable error on Save. */
    }
    return AppPage(
      title: widget.existing == null ? 'Add list item' : 'Edit item / estimate',
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _form,
              child: PagePadding(
                children: [
                  CatalogPicker(
                    product: true,
                    value: _product,
                    enabled: widget.existing == null,
                    onChanged: (v) => setState(() {
                      _product = v;
                      _unit = baseUnit(_kind);
                      _basis = null;
                      _sourceId = null;
                      _mode = 'none';
                      _quantity.clear();
                      _manual.clear();
                    }),
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: _quantityChanged,
                    decoration: const InputDecoration(
                      labelText: English.quantityYouNeed,
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
                    onChanged: (v) {
                      _unit = v!;
                      _quantityChanged(_quantity.text);
                    },
                  ),
                  fieldGap(),
                  DropdownButtonFormField<String>(
                    itemHeight: null,
                    initialValue: _mode,
                    key: ValueKey('estimate_$_mode'),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: English.howToEstimate,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(English.notEstimatedYet),
                      ),
                      DropdownMenuItem(
                        value: 'manual',
                        child: Text(English.manualTotalForThisItem),
                      ),
                      DropdownMenuItem(
                        value: 'price',
                        child: Text(English.useARecordedPrice),
                      ),
                    ],
                    onChanged: (v) => setState(() => _mode = v!),
                  ),
                  fieldGap(),
                  if (_mode == 'manual') ...[
                    TextFormField(
                      controller: _manual,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: English.estimatedTotalPhp,
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
                    const Text(
                      English
                          .changingTheRequestedQuantityClearsAManualEstimateRe,
                    ),
                  ],
                  if (_mode == 'price') ...[
                    if (_basis != null)
                      Text(
                        '${_basis!['store_name']} · observed ${_basis!['observed_on']}\n${money(_basis!['quoted_centavos'] as int)} / ${quantityLabel(_basis!['offered_quantity_base'] as int, _kind)} · ${_basis!['selling_mode']}',
                      ),
                    OutlinedButton.icon(
                      onPressed: _choosePrice,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        _basis == null
                            ? 'Choose recorded price'
                            : 'Refresh / choose price',
                      ),
                    ),
                    if (preview != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          preview,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    const Text(
                      English.thisEstimateKeepsTheSelectedPriceBasisLaterPrice,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SaveBar(busy: _busy, onSave: _save),
        ],
      ),
    );
  }
}
