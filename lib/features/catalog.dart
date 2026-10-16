import '../app/english.dart';

import 'package:flutter/material.dart' hide Row;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/controller.dart';
import '../core/models.dart';
import 'common.dart';

class CatalogForm extends ConsumerStatefulWidget {
  const CatalogForm({super.key, required this.product, this.existing});
  final bool product;
  final Row? existing;
  @override
  ConsumerState<CatalogForm> createState() => _CatalogFormState();
}

class _CatalogFormState extends ConsumerState<CatalogForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _brand,
      _variant,
      _category,
      _barangay,
      _landmark;
  late String _kind, _id;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final row = widget.existing ?? <String, dynamic>{};
    _id = row['id'] as String? ?? newId();
    _name = TextEditingController(text: row['name'] as String? ?? '');
    _brand = TextEditingController(text: row['brand'] as String? ?? '');
    _variant = TextEditingController(
      text: row['variant_grade'] as String? ?? '',
    );
    _category = TextEditingController(
      text: row['category'] as String? ?? 'Uncategorized',
    );
    _barangay = TextEditingController(
      text: row['barangay_text'] as String? ?? '',
    );
    _landmark = TextEditingController(text: row['landmark'] as String? ?? '');
    _kind = row['quantity_kind'] as String? ?? 'mass';
  }

  @override
  void dispose() {
    for (final field in [
      _name,
      _brand,
      _variant,
      _category,
      _barangay,
      _landmark,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final data = ref.read(appProvider).requireValue;
    final existingRows = widget.product ? data.products : data.stores;
    final duplicate = existingRows.any(
      (r) =>
          r['id'] != _id &&
          (r['name'] as String).trim().toLowerCase() ==
              _name.text.trim().toLowerCase(),
    );
    if (duplicate &&
        !await confirm(
          context,
          'Similar name already saved',
          'Check the brand, variant, grade, or store location. Create a separate entry only if it represents a different product or store.',
          action: 'Save separate entry',
        )) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    final row = <String, dynamic>{
      ...?widget.existing,
      'id': _id,
      'name': _name.text.trim(),
      'archived': widget.existing?['archived'] ?? false,
    };
    if (widget.product) {
      row.addAll({
        'brand': _brand.text.trim(),
        'variant_grade': _variant.text.trim(),
        'category': _category.text.trim().isEmpty
            ? 'Uncategorized'
            : _category.text.trim(),
        'quantity_kind': _kind,
      });
    } else {
      row.addAll({
        'barangay_text': _barangay.text.trim(),
        'landmark': _landmark.text.trim(),
      });
    }
    final ok = await change(
      context,
      ref,
      (repo) => widget.product ? repo.saveProduct(row) : repo.saveStore(row),
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
    title:
        '${widget.existing == null ? 'Add' : 'Edit'} ${widget.product ? 'product' : 'store'}',
    child: Column(
      children: [
        Expanded(
          child: Form(
            key: _form,
            child: PagePadding(
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.product
                        ? 'Product name'
                        : 'Store or stall name',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name.' : null,
                ),
                fieldGap(),
                if (widget.product) ...[
                  const Text(
                    English
                        .oneEntryRepresentsOneSpecificProductIncludeBrandVariety,
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _brand,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: English.brandIfRelevant,
                    ),
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _variant,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: English.variantVarietyGradeOrSize,
                    ),
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _category,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: English.category,
                    ),
                  ),
                  fieldGap(),
                  DropdownButtonFormField<String>(
                    itemHeight: null,
                    initialValue: _kind,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: English.measuredBy,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'mass',
                        child: Text(English.massGramsKilograms),
                      ),
                      DropdownMenuItem(
                        value: 'volume',
                        child: Text(English.volumeMlLiters),
                      ),
                      DropdownMenuItem(
                        value: 'count',
                        child: Text(English.countPieces),
                      ),
                    ],
                    onChanged: (v) => setState(() => _kind = v!),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      English.onceRecordsUseThisProductItsMeasurementKindCannot,
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _barangay,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: English.barangayOrAreaOptional,
                    ),
                  ),
                  fieldGap(),
                  TextFormField(
                    controller: _landmark,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText: English.landmarkOptional,
                    ),
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

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key, required this.products});
  final bool products;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider).asData?.value;
    if (data == null) {
      return const AppPage(
        title: English.catalog,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = products ? data.products : data.stores;
    return AppPage(
      title: products ? 'Manage products' : 'Manage stores',
      child: PagePadding(
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<String>(
                builder: (_) => CatalogForm(product: products),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(products ? 'Add product' : 'Add store'),
          ),
          fieldGap(),
          if (rows.isEmpty)
            const Text(English.noEntriesYetAddOneHereOrWhileRecording),
          ...rows.map(
            (r) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      products ? productName(r) : r['name'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      r['archived'] == true
                          ? 'Archived · kept in your history'
                          : products
                          ? r['category'] as String
                          : (r['barangay_text'] as String? ?? ''),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<String>(
                              builder: (_) =>
                                  CatalogForm(product: products, existing: r),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text(English.edit),
                        ),
                        TextButton(
                          onPressed: () async {
                            await change(
                              context,
                              ref,
                              (repo) => products
                                  ? repo.saveProduct({
                                      ...r,
                                      'archived': r['archived'] != true,
                                    })
                                  : repo.saveStore({
                                      ...r,
                                      'archived': r['archived'] != true,
                                    }),
                            );
                          },
                          child: Text(
                            r['archived'] == true ? 'Restore entry' : 'Archive',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CatalogPicker extends ConsumerWidget {
  const CatalogPicker({
    super.key,
    required this.product,
    required this.value,
    required this.onChanged,
    this.optional = false,
    this.enabled = true,
  });
  final bool product, optional, enabled;
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider).requireValue;
    final rows = (product ? data.products : data.stores)
        .where((r) => r['archived'] != true || r['id'] == value)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          itemHeight: null,
          key: ValueKey('${product}_${value}_${rows.length}'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: product
                ? 'Specific product'
                : optional
                ? 'Store (optional)'
                : 'Store or stall',
          ),
          items: [
            if (optional)
              const DropdownMenuItem(
                value: '',
                child: Text(English.notSpecified),
              ),
            ...rows.map(
              (r) => DropdownMenuItem(
                value: r['id'] as String,
                child: Text(product ? productName(r) : r['name'] as String),
              ),
            ),
          ],
          validator: (v) => !optional && (v == null || v.isEmpty)
              ? 'Choose or add ${product ? 'a product' : 'a store'}.'
              : null,
          onChanged: enabled ? onChanged : null,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: !enabled
                ? null
                : () async {
                    final id = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CatalogForm(product: product),
                      ),
                    );
                    if (id != null) onChanged(id);
                  },
            icon: const Icon(Icons.add),
            label: Text('Add ${product ? 'product' : 'store'} here'),
          ),
        ),
      ],
    );
  }
}
