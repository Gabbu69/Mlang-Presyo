import '../app/english.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/controller.dart';
import '../app/strings.dart';
import '../core/domain.dart';
import '../core/location.dart';
import 'common.dart';
import 'lists.dart';
import 'location.dart';
import 'prices.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _allAreas = false;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider).requireValue;
    final area = ShoppingArea.fromSettings(data.settings);
    final active = data.lists.where((l) => l['status'] == 'active').toList()
      ..sort(compareUpdatedRows);
    final recent =
        [...pricesInArea(data, _allAreas ? const ShoppingArea() : area)]..sort(
          (a, b) => (b['observed_on'] as String).compareTo(
            a['observed_on'] as String,
          ),
        );
    return PagePadding(
      children: [
        if (MediaQuery.textScalerOf(context).scale(1) <= 1.5) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  English.yourPrivateMarketNotebook,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  English.recordPricesPlanPurchases,
                  style: TextStyle(color: Color(0xFFF8F2E5), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PriceForm()),
              ),
              icon: const Icon(Icons.add),
              label: const Text(English.addPrice),
            ),
            OutlinedButton.icon(
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
              icon: const Icon(Icons.playlist_add),
              label: const Text(English.createList),
            ),
          ],
        ),
        fieldGap(),
        const ShoppingAreaCard(),
        const SectionTitle('Your next shopping trip'),
        if (active.isEmpty)
          const EmptyCard(
            icon: Icons.checklist,
            title: English.startWithWhatYouNeed,
            message: English.createAShoppingListThenAddProductsAndAn,
          )
        else ...[
          Text(
            active.first['title'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${data.listItems(active.first['id'] as String).where((i) => i['status'] == 'needed').length} items still needed',
          ),
          ListSummary(data: data, listId: active.first['id'] as String),
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    ListDetail(listId: active.first['id'] as String),
              ),
            ),
            child: const Text(English.openShoppingList),
          ),
        ],
        const SectionTitle('Recently recorded'),
        AreaScopeControls(
          data: data,
          area: area,
          allAreas: _allAreas,
          showChangeArea: false,
          onAllAreasChanged: (value) => setState(() => _allAreas = value),
        ),
        if (recent.isEmpty)
          EmptyCard(
            icon: Icons.price_change_outlined,
            title: !area.isAll && !_allAreas
                ? English.noPricesInArea
                : English.rememberAPriceForNextTime,
            message: !area.isAll && !_allAreas
                ? 'Your phone location filters your own saved records. Add a store and price here, tag an existing store, or show all areas.'
                : English.startYourPriceNotebookByRecordingAnItemYou,
          )
        else
          ...recent
              .take(3)
              .map(
                (price) => PriceCard(
                  price: price,
                  data: data,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetail(
                        productId: price['product_id'] as String,
                        initialAllAreas: _allAreas,
                      ),
                    ),
                  ),
                ),
              ),
        if (recent.isEmpty && !area.isAll && !_allAreas)
          const AreaPriceEmptyActions(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(AppStrings.priceReminder),
        ),
      ],
    );
  }
}
