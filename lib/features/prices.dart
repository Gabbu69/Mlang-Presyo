import '../app/english.dart';

import 'package:flutter/material.dart' hide Row;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/controller.dart';
import '../app/strings.dart';
import '../core/domain.dart';
import '../core/models.dart';
import 'catalog.dart';
import 'common.dart';
import 'lists.dart';

class PriceForm extends ConsumerStatefulWidget {
  const PriceForm({super.key, this.existing, this.productId});
  final Row? existing;
  final String? productId;
  @override
  ConsumerState<PriceForm> createState() => _PriceFormState();
}

class _PriceFormState extends ConsumerState<PriceForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount, _quantity, _notes;
  late final String _id;
  String? _product, _store;
  String _unit = 'g', _mode = 'loose', _offer = 'regular', _source = 'observed';
  late String _date;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    _id = row?['id'] as String? ?? newId();
    _product = row?['product_id'] as String? ?? widget.productId;
    _store = row?['store_id'] as String?;
    _amount = TextEditingController(
      text: row == null ? '' : moneyInput(row['quoted_centavos'] as int),
    );
    _quantity = TextEditingController(
      text: row?['offered_quantity_base']?.toString() ?? '',
    );
    _notes = TextEditingController(text: row?['notes'] as String? ?? '');
    _mode = row?['selling_mode'] as String? ?? 'loose';
    _offer = row?['offer_type'] as String? ?? 'regular';
    _source = row?['source_type'] as String? ?? 'observed';
    _date = row?['observed_on'] as String? ?? dateText(manilaToday());
    if (_product != null) {
      _unit = baseUnit(
        ref.read(appProvider).requireValue.product(_product!)['quantity_kind']
            as String,
      );
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _kind => _product == null
      ? 'mass'
      : ref.read(appProvider).requireValue.product(_product!)['quantity_kind']
            as String;
  String? _moneyValidator(String? v) {
    try {
      parseMoney(v ?? '', positive: true);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String? _quantityValidator(String? v) {
    try {
      parseQuantity(v ?? '', _unit, _kind);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await change(
      context,
      ref,
      (repo) => repo.savePrice({
        ...?widget.existing,
        'id': _id,
        'product_id': _product!,
        'store_id': _store!,
        'quoted_centavos': parseMoney(_amount.text, positive: true),
        'offered_quantity_base': parseQuantity(_quantity.text, _unit, _kind),
        'selling_mode': _mode,
        'offer_type': _offer,
        'source_type': _source,
        'observed_on': _date,
        'notes': _notes.text.trim(),
      }),
      success: 'Price saved in your notebook.',
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
    return AppPage(
      title: widget.existing == null ? 'Add price' : 'Edit price',
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _form,
              child: PagePadding(
                children: [
                  const Text(
                    English.recordTheTotalPriceForAMeasuredQuantityThis,
                  ),
                  fieldGap(),
                  CatalogPicker(
                    product: true,
                    value: _product,
                    onChanged: (v) {
                      final previousKind = _kind;
                      setState(() {
                        _product = v;
                        if (_kind != previousKind) {
                          _unit = baseUnit(_kind);
                          _quantity.clear();
                        }
                      });
                    },
                  ),
                  fieldGap(),
                  CatalogPicker(
                    product: false,
                    value: _store,
                    onChanged: (v) => setState(() => _store = v),
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: English.totalQuotedPricePhp,
                      prefixText: '₱ ',
                    ),
                    validator: _moneyValidator,
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: English.quantityCoveredByThisPrice,
                    ),
                    validator: _quantityValidator,
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
                  DropdownButtonFormField<String>(
                    itemHeight: null,
                    initialValue: _mode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: English.howIsItSold,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'loose',
                        child: Text(English.looseMeasuredAmount),
                      ),
                      DropdownMenuItem(
                        value: 'packaged',
                        child: Text(English.packagedWholePacksOnly),
                      ),
                    ],
                    onChanged: (v) => setState(() => _mode = v!),
                  ),
                  fieldGap(),
                  const Text(English.forPacksOrTraysEnterTheContentsForExample),
                  fieldGap(),
                  DateField(
                    value: _date,
                    onChanged: (v) => setState(() => _date = v),
                  ),
                  fieldGap(),
                  DropdownButtonFormField<String>(
                    itemHeight: null,
                    initialValue: _source,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: English.source,
                    ),
                    items: ['observed', 'purchase', 'seller_quote']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(sourceName(s)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _source = v!),
                  ),
                  fieldGap(),
                  DropdownButtonFormField<String>(
                    itemHeight: null,
                    initialValue: _offer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: English.offerType,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'regular',
                        child: Text(English.regular),
                      ),
                      DropdownMenuItem(
                        value: 'promotional',
                        child: Text(English.promotionalExcludedFromRanking),
                      ),
                      DropdownMenuItem(
                        value: 'conditional',
                        child: Text(English.conditionalExcludedFromRanking),
                      ),
                    ],
                    onChanged: (v) => setState(() => _offer = v!),
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _notes,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: English.privateNoteOptional,
                    ),
                  ),
                  fieldGap(),
                  const Text(AppStrings.priceReminder),
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

class PricesPage extends ConsumerStatefulWidget {
  const PricesPage({super.key});
  @override
  ConsumerState<PricesPage> createState() => _PricesPageState();
}

class _PricesPageState extends ConsumerState<PricesPage> {
  String _search = '', _category = '', _store = '';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider).requireValue;
    final categories =
        data.products.map((p) => p['category'] as String).toSet().toList()
          ..sort();
    // Catalog edits and replacement restores can remove a selected filter.
    // Derive valid selections so both the results and the form field recover.
    final category = categories.contains(_category) ? _category : '';
    final store = data.stores.any((s) => s['id'] == _store) ? _store : '';
    final rows =
        data.prices.where((r) {
          final product = data.product(r['product_id'] as String);
          return productName(
                product,
              ).toLowerCase().contains(_search.toLowerCase()) &&
              (category.isEmpty || product['category'] == category) &&
              (store.isEmpty || r['store_id'] == store);
        }).toList()..sort(
          (a, b) => (b['observed_on'] as String).compareTo(
            a['observed_on'] as String,
          ),
        );
    return PagePadding(
      children: [
        Text(
          English.myPriceRecords,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(English.yourOwnDatedObservationsAroundMLang),
        fieldGap(),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PriceForm()),
          ),
          icon: const Icon(Icons.add),
          label: const Text(English.addPrice),
        ),
        fieldGap(),
        TextField(
          decoration: const InputDecoration(
            labelText: English.searchProducts,
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        fieldGap(),
        DropdownButtonFormField<String>(
          itemHeight: null,
          key: ValueKey('category_$category'),
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: English.category),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text(English.allCategories),
            ),
            ...categories.map(
              (c) => DropdownMenuItem(value: c, child: Text(c)),
            ),
          ],
          onChanged: (v) => setState(() => _category = v!),
        ),
        fieldGap(),
        DropdownButtonFormField<String>(
          itemHeight: null,
          key: ValueKey('store_$store'),
          initialValue: store,
          isExpanded: true,
          decoration: const InputDecoration(labelText: English.store),
          items: [
            const DropdownMenuItem(value: '', child: Text(English.allStores)),
            ...data.stores.map(
              (s) => DropdownMenuItem(
                value: s['id'] as String,
                child: Text(s['name'] as String),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _store = v!),
        ),
        fieldGap(),
        if (rows.isEmpty)
          EmptyCard(
            icon: Icons.price_change_outlined,
            title: data.prices.isEmpty
                ? 'Begin your price notebook'
                : 'No matching records',
            message: data.prices.isEmpty
                ? 'Record an item you buy regularly. Your first price stays available offline.'
                : 'Try another product, category, or store.',
          ),
        ...rows.map(
          (r) => PriceCard(
            price: r,
            data: data,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    ProductDetail(productId: r['product_id'] as String),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PriceCard extends StatelessWidget {
  const PriceCard({
    super.key,
    required this.price,
    required this.data,
    this.onTap,
    this.actions,
  });
  final Row price;
  final AppData data;
  final VoidCallback? onTap;
  final Widget? actions;
  @override
  Widget build(BuildContext context) {
    final product = data.product(price['product_id'] as String);
    final store = data.store(price['store_id'] as String);
    final kind = product['quantity_kind'] as String;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName(product),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${money(price['quoted_centavos'] as int)} / ${quantityOf(product, price['offered_quantity_base'] as int)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '${money(normalizedCentavos(price, kind))} per ${kind == 'mass'
                    ? 'kg'
                    : kind == 'volume'
                    ? 'L'
                    : 'piece'} · ${price['selling_mode']}',
              ),
              const SizedBox(height: 8),
              Text(store?['name'] as String? ?? 'Archived store'),
              Text(
                '${price['observed_on']} · ${ageLabel(price['observed_on'] as String)}',
              ),
              Text(
                '${sourceName(price['source_type'] as String)} · ${price['offer_type']}',
              ),
              if ((price['notes'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(price['notes'] as String),
                ),
              ?actions,
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetail extends ConsumerStatefulWidget {
  const ProductDetail({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends ConsumerState<ProductDetail> {
  bool _older = false;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider).requireValue;
    final product = data.product(widget.productId);
    final candidates = comparablePrices(
      data.prices,
      widget.productId,
      older: _older,
    );
    final history =
        data.prices.where((p) => p['product_id'] == widget.productId).toList()
          ..sort(
            (a, b) => (b['observed_on'] as String).compareTo(
              a['observed_on'] as String,
            ),
          );
    return AppPage(
      title: productName(product),
      child: PagePadding(
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PriceForm(productId: widget.productId),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text(English.recordAnotherPrice),
          ),
          const SectionTitle('Compare recorded offers'),
          const Text(English.lowestRecordedUnitPriceAmongTheseRecordsABetter),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(English.showOlderRecords),
            subtitle: const Text(
              English.datesRemainVisibleOlderPricesMayHaveChanged,
            ),
            value: _older,
            onChanged: (v) => setState(() => _older = v),
          ),
          if (candidates.isEmpty)
            const EmptyCard(
              icon: Icons.history,
              title: English.noRecentComparableRecords,
              message: English.recordARegularPriceOrEnableShowOlderRecords,
            ),
          ...candidates.map(
            (r) => PriceCard(
              price: r,
              data: data,
              actions: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => chooseListForPrice(context, ref, product, r),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text(English.useForList),
                ),
              ),
            ),
          ),
          const Text(AppStrings.priceReminder),
          const SectionTitle('Price history'),
          ...history.map(
            (r) => PriceCard(
              price: r,
              data: data,
              actions: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PriceForm(existing: r),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(English.edit),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      if (await confirm(
                            context,
                            'Delete price record?',
                            'Purchase history and frozen shopping estimates will be kept.',
                            action: 'Delete record',
                          ) &&
                          context.mounted) {
                        await change(
                          context,
                          ref,
                          (repo) => repo.deletePrice(r['id'] as String),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(English.delete),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
