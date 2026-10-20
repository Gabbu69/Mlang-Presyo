import '../app/english.dart';

import 'package:flutter/material.dart' hide Row;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/controller.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../platform/location_service.dart';
import 'common.dart';

class ShoppingAreaPage extends ConsumerStatefulWidget {
  const ShoppingAreaPage({
    super.key,
    this.locationService = const LocationService(),
    this.usePhoneOnOpen = false,
  });
  final LocationService locationService;
  final bool usePhoneOnOpen;
  @override
  ConsumerState<ShoppingAreaPage> createState() => _ShoppingAreaPageState();
}

class _ShoppingAreaPageState extends ConsumerState<ShoppingAreaPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late String _mode;
  late int _radius;
  LocationFix? _fix;
  bool _busy = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    final area = ShoppingArea.fromSettings(
      ref.read(appProvider).requireValue.settings,
    );
    _label = TextEditingController(text: area.label);
    _mode = area.mode;
    _radius = area.radiusM;
    if (area.isNearby) {
      _fix = LocationFix(
        latitudeE6: area.latitudeE6!,
        longitudeE6: area.longitudeE6!,
        accuracyM: area.accuracyM!,
        capturedAtUtc: area.capturedAtUtc!,
      );
    }
    if (widget.usePhoneOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _locate();
      });
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _locationError = null;
    });
    try {
      final fix = await widget.locationService.currentLocation();
      if (!mounted) return;
      setState(() {
        _fix = fix;
        _mode = 'nearby';
        // GPS supplies coordinates, never a detected city/municipality name.
        _label.clear();
      });
    } on LocationException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationError =
              'Location was not available. You can enter a city or '
              'municipality manually, retry GPS, or use All areas.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_mode == 'nearby' && _fix == null) {
      setState(
        () => _locationError =
            'Tap Use my location to set a saved center, '
            'or choose Manual area or All areas.',
      );
      return;
    }
    final fix = _mode == 'nearby' ? _fix : null;
    final area = ShoppingArea(
      mode: _mode,
      label: _mode == 'all' ? '' : _label.text.trim(),
      latitudeE6: fix?.latitudeE6,
      longitudeE6: fix?.longitudeE6,
      accuracyM: fix?.accuracyM,
      capturedAtUtc: fix?.capturedAtUtc,
      radiusM: _radius,
    );
    setState(() => _busy = true);
    final ok = await change(
      context,
      ref,
      (repo) => repo.saveShoppingArea(area.toRow()),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: English.shoppingArea,
    busy: _busy,
    child: Column(
      children: [
        Expanded(
          child: Form(
            key: _form,
            child: PagePadding(
              children: [
                const Text(
                  'Use your own price notebook anywhere in the Philippines. '
                  'PHP amounts and Manila calendar dates stay the same.',
                ),
                fieldGap(),
                const Text(
                  'GPS is optional and requested only when you tap its button. '
                  'No map, city lookup or price feed is downloaded.',
                ),
                fieldGap(),
                DropdownButtonFormField<String>(
                  key: ValueKey(_mode),
                  initialValue: _mode,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Show recorded prices from',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All areas')),
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text('Manual area'),
                    ),
                    DropdownMenuItem(
                      value: 'nearby',
                      child: Text('Nearby saved stores'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _mode = value!),
                ),
                fieldGap(),
                if (_mode != 'all') ...[
                  TextFormField(
                    controller: _label,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: _mode == 'manual'
                          ? 'City or municipality'
                          : 'Your area label (optional)',
                    ),
                    validator: (value) =>
                        _mode == 'manual' && (value?.trim().isEmpty ?? true)
                        ? 'Enter a city or municipality.'
                        : null,
                  ),
                  fieldGap(),
                  const Text(
                    'Area labels are entered by you. Matching ignores letter '
                    'case and extra spaces; it does not merge products or stores.',
                  ),
                  fieldGap(),
                ],
                OutlinedButton.icon(
                  onPressed: _busy ? null : _locate,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    _locationError != null
                        ? English.retryLocation
                        : _fix == null
                        ? English.useMyLocation
                        : English.refreshLocation,
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
                if (_locationError != null) ...[
                  fieldGap(),
                  Semantics(liveRegion: true, child: Text(_locationError!)),
                  TextButton(
                    onPressed: () => setState(() {
                      _mode = 'manual';
                      _locationError = null;
                    }),
                    child: const Text(English.enterAreaManually),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _mode = 'all';
                      _locationError = null;
                    }),
                    child: const Text(English.useAllAreas),
                  ),
                ],
                if (_mode == 'nearby') ...[
                  fieldGap(),
                  DropdownButtonFormField<int>(
                    initialValue: _radius,
                    itemHeight: null,
                    decoration: const InputDecoration(
                      labelText: 'Nearby radius',
                    ),
                    items: const [5000, 10000, 25000]
                        .map(
                          (radius) => DropdownMenuItem(
                            value: radius,
                            child: Text('${radius ~/ 1000} km'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _radius = value!),
                  ),
                  if (_fix != null) ...[
                    fieldGap(),
                    LocationFixText(fix: _fix!),
                  ],
                  fieldGap(),
                  const Text(
                    'Nearby uses approximate straight-line distance from this '
                    'saved center. It does not track travel or update in the background. '
                    'Stores without GPS tags are excluded; All areas shows them again.',
                  ),
                ],
                fieldGap(),
                const Text(
                  'Tap Save to apply this area. A new GPS fix is not saved '
                  'automatically. Your existing estimates and purchase history stay frozen.',
                ),
                fieldGap(),
                const Text(
                  'Area labels and optional coordinates are stored locally. '
                  'Unencrypted JSON/CSV exports may include them. Share exports carefully.',
                ),
              ],
            ),
          ),
        ),
        SaveBar(busy: _busy, onSave: _save, label: English.saveShoppingArea),
      ],
    ),
  );
}

class ShoppingAreaCard extends ConsumerWidget {
  const ShoppingAreaCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ShoppingArea.fromSettings(
      ref.watch(appProvider).requireValue.settings,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              English.shoppingArea,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(area.description),
            if (area.isNearby)
              Text('Saved GPS center · about ±${area.accuracyM} m accuracy'),
            if (area.isNearby)
              Text(
                'Captured: ${area.capturedAtUtc!.toUtc().toIso8601String()}',
              ),
            if (area.isNearby)
              TextButton.icon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ShoppingAreaPage(usePhoneOnOpen: true),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text(English.refreshLocation),
              ),
            TextButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const ShoppingAreaPage()),
              ),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text(English.changeShoppingArea),
            ),
          ],
        ),
      ),
    );
  }
}

/// The All areas escape hatch is local to the current screen/chooser. It does
/// not overwrite the owner's saved shopping-area choice or frozen estimates.
class AreaScopeControls extends StatelessWidget {
  const AreaScopeControls({
    super.key,
    required this.data,
    required this.area,
    required this.allAreas,
    required this.onAllAreasChanged,
    this.showChangeArea = true,
  });
  final AppData data;
  final ShoppingArea area;
  final bool allAreas;
  final ValueChanged<bool> onAllAreasChanged;
  final bool showChangeArea;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(allAreas || area.isAll ? 'All areas' : area.description),
      if (!area.isAll)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(English.showAllAreas),
          value: allAreas,
          onChanged: onAllAreasChanged,
        ),
      if (!area.isAll && !allAreas)
        Text(
          area.isNearby
              ? '${unlocatedStoreCount(data)} stores without GPS tags are excluded. '
                    'Use All areas to include unknown or distant stores. Distances are approximate.'
              : 'Only matching user-entered area labels are shown. Stores without '
                    'this label are excluded. Use All areas to see your whole notebook.',
        ),
      if (showChangeArea)
        TextButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const ShoppingAreaPage()),
          ),
          icon: const Icon(Icons.location_on_outlined),
          label: const Text(English.changeShoppingArea),
        ),
    ],
  );
}

class LocationFixText extends StatelessWidget {
  const LocationFixText({super.key, required this.fix});
  final LocationFix fix;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('GPS: ${coordinateText(fix.latitudeE6, fix.longitudeE6)}'),
      Text('Phone accuracy: about ±${fix.accuracyM} m'),
      Text('Captured: ${fix.capturedAtUtc.toUtc().toIso8601String()}'),
    ],
  );
}

/// Store tags are user-entered metadata, never an inferred city or price feed.
class StoreLocationText extends StatelessWidget {
  const StoreLocationText({super.key, required this.store, this.area});
  final Row store;
  final ShoppingArea? area;
  @override
  Widget build(BuildContext context) {
    final label = store['area_text'] as String?;
    final distance = area == null ? null : storeDistance(area!, store);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label == null ? English.areaNotEntered : 'Area: $label'),
        if (distance != null) Text(approximateDistance(distance)),
        if (validCoordinatePair(
          store['latitude_e6'],
          store['longitude_e6'],
        )) ...[
          Text('Store GPS tag · about ±${store['accuracy_m']} m accuracy'),
          Text('GPS captured: ${store['location_captured_at_utc']}'),
        ] else
          const Text(English.noStoreLocationTag),
      ],
    );
  }
}
