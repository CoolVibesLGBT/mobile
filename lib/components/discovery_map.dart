import '../l10n/l10n.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/geo.dart';
import '../core/session.dart';
import 'components.dart';
import 'game_map.dart';
import 'radar_profile_card.dart';
import '../screens/location_picker.dart';

class DiscoveryMap extends StatefulWidget {
  final String action;
  final int limit;
  final Json coordinates;
  final ValueChanged<Json>? onCoordinatesChanged;
  const DiscoveryMap({
    super.key,
    required this.action,
    this.limit = 60,
    required this.coordinates,
    this.onCoordinatesChanged,
  });
  @override
  State<DiscoveryMap> createState() => _DiscoveryMapState();
}

class _DiscoveryMapState extends State<DiscoveryMap> {
  final map = GameMapController();
  final records = <Json>[];
  Json? selected;
  String? error;
  Timer? debounce;
  bool loading = false, locating = false;
  int generation = 0;
  late Json center = {
    'latitude': 41.0082,
    'longitude': 28.9784,
    ...widget.coordinates,
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fetch();
    });
  }

  @override
  void didUpdateWidget(DiscoveryMap old) {
    super.didUpdateWidget(old);
    if (old.coordinates.toString() != widget.coordinates.toString() &&
        center.toString() != widget.coordinates.toString()) {
      center = {...center, ...widget.coordinates};
      map.flyTo(center['latitude'], center['longitude'], zoom: 12.5);
      fetch();
    }
  }

  Future<void> fetch() async {
    final current = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await AppScope.of(
        context,
      ).api.call(widget.action, body: {...center, 'limit': widget.limit});
      if (mounted && generation == current) {
        setState(() {
          records
            ..clear()
            ..addAll(RecordPage.parse(response).records);
        });
      }
    } catch (e) {
      if (mounted && generation == current) setState(() => error = '$e');
    } finally {
      if (mounted && generation == current) setState(() => loading = false);
    }
  }

  Future<void> moveTo(Json location) async {
    final point = coordinatesOf(location);
    if (point == null || !mounted) return;
    debounce?.cancel();
    setState(() {
      center = point;
      selected = null;
    });
    widget.onCoordinatesChanged?.call(point);
    await map.flyTo(point['latitude'], point['longitude'], zoom: 12.5);
    if (mounted) await fetch();
  }

  Future<void> teleport() async {
    final point = await sheet<Json>(
      context,
      LocationPickerScreen(initial: center, teleport: true),
    );
    if (point != null && mounted) await moveTo(point);
  }

  Future<void> myLocation() async {
    if (locating) return;
    setState(() => locating = true);
    await perform(context, () async {
      final point = await currentPosition();
      if (mounted) {
        await moveTo({
          'latitude': point.latitude,
          'longitude': point.longitude,
        });
      }
    });
    if (mounted) setState(() => locating = false);
  }

  Json author(Json record) => widget.action == 'user.check_in_fetch'
      ? object(record['author'] ?? record['user'] ?? record['owner'])
      : record;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: GameMap(
          controller: map,
          zoom: 12.5,
          controlsBottom: MediaQuery.paddingOf(context).bottom + 206,
          latitude: center['latitude'],
          longitude: center['longitude'],
          player: widget.coordinates.isEmpty ? null : widget.coordinates,
          markers: [
            for (final record in records)
              if (coordinatesOf(record) != null)
                {
                  'id': recordId(record),
                  ...coordinatesOf(record)!,
                  'imageUrl': assetUrl(
                    author(record)['avatar'] ?? author(record)['avatar_url'],
                    variant: 'small',
                  ),
                  'initial': personName(author(record)),
                  if (selected != null &&
                      recordId(selected!) == recordId(author(record)))
                    'label': plainText(record['content']),
                },
          ],
          onMove: (point) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 700), () {
              if (!mounted) return;
              center = {
                'latitude': point['latitude'],
                'longitude': point['longitude'],
              };
              fetch();
            });
          },
          onMarker: (id) {
            final record = records.where((r) => recordId(r) == id).firstOrNull;
            if (record != null) setState(() => selected = author(record));
          },
          onPress: () => setState(() => selected = null),
        ),
      ),
      if (loading)
        const Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(),
        ),
      if (error != null)
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 16,
          right: 16,
          child: ScreenStatus(error: error, retry: fetch, compact: true),
        ),
      PositionedDirectional(
        end: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
        child: Column(
          children: [
            AppIconButton(
              dimension: 48,
              tooltip: context.l10n.changeLocation,
              icon: const Icon(Icons.travel_explore),
              onPressed: teleport,
            ),
            const SizedBox(height: 10),
            AppIconButton(
              dimension: 48,
              tooltip: context.l10n.myLocation,
              icon: locating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator.adaptive(),
                    )
                  : const Icon(Icons.my_location),
              onPressed: locating ? null : myLocation,
            ),
          ],
        ),
      ),
      if (selected != null)
        Positioned.fill(
          child: RadarProfileCard(
            key: ValueKey(recordId(selected!)),
            user: selected!,
            onClose: () => setState(() => selected = null),
          ),
        ),
    ],
  );
}
