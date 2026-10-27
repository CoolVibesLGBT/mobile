import '../l10n/l10n.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../core/geo.dart';
import '../core/place_search.dart';
import '../components/components.dart';
import '../components/game_map.dart';
import '../components/glass_surface.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../design/app_design.dart';

/// Telegram LocationPickerController (glass layout): the map fills the screen
/// behind a list that starts 300pt down and scrolls over it. Dragging the map
/// enters location picking: the map takes the whole screen, the list slides
/// away, the pin lifts while the camera moves and a 52pt "Send Location"
/// button with the address appears. Search opens a results layer with its
/// input at the bottom.
class LocationPickerScreen extends StatefulWidget {
  final Json? initial;
  final bool teleport;
  const LocationPickerScreen({super.key, this.initial, this.teleport = false});
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

/// LocationPickerControllerNode metrics.
abstract final class _Picker {
  static const topInset = 300.0;
  static const button = 44.0, edge = 16.0;

  /// topEdgeEffectView: 80pt of the list colour at 0.65; bottom is 88pt.
  static const topEdge = 80.0, bottomEdge = 88.0;
  static const sendHeight = 52.0, sendSide = 36.0, sendBottom = 14.0;
  static const rowHeight = 64.0, venueHeight = 58.0, icon = 40.0;

  /// requestLayout(.animated(duration: 0.45, curve: .spring)).
  static final spring = SpringDescription(
    mass: 5,
    stiffness: 900,
    damping: 104,
  );
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with TickerProviderStateMixin {
  final map = GameMapController();
  final scroll = ScrollController();
  late final picking = AnimationController.unbounded(vsync: this);
  late final lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late Json point =
      coordinatesOf(widget.initial ?? {}) ?? {...defaultDiscoveryCoordinates};
  Json? current;
  final places = <Json>[], results = <Json>[];
  Timer? debounce;
  CancelToken? request, searchRequest;
  String language = 'en', query = '';
  String? next, error, searchError;
  bool locating = false,
      loading = false,
      started = false,
      isPicking = false,
      searching = false,
      searchLoading = false;
  int generation = 0, searchGeneration = 0;
  final searchInput = TextEditingController();
  final searchFocus = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    language = Localizations.localeOf(context).languageCode;
    if (!started) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (widget.initial == null && !AppScope.of(context).api.isPreview) {
          await locate(initial: true);
        } else {
          fetch();
        }
      });
    }
  }

  @override
  void dispose() {
    generation++;
    searchGeneration++;
    debounce?.cancel();
    request?.cancel();
    searchRequest?.cancel();
    scroll.dispose();
    picking.dispose();
    lift.dispose();
    searchInput.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void animatePicking(bool value) {
    if (isPicking == value) return;
    setState(() => isPicking = value);
    if (MediaQuery.disableAnimationsOf(context)) {
      picking.value = value ? 1 : 0;
    } else {
      picking.animateWith(
        SpringSimulation(
          _Picker.spring,
          picking.value,
          value ? 1 : 0,
          picking.velocity,
        ),
      );
    }
  }

  /// The user started moving the map: pick on the map with a lifted pin.
  void moveStarted(bool user) {
    if (!user) return;
    if (!MediaQuery.disableAnimationsOf(context)) lift.forward();
    if (scroll.hasClients && scroll.offset > 0) scroll.jumpTo(0);
    animatePicking(true);
  }

  void moved(Json value) {
    if (!MediaQuery.disableAnimationsOf(context)) {
      lift.animateBack(0, curve: Curves.easeOutBack);
    }
    final nextPoint = coordinatesOf(value);
    if (nextPoint == null ||
        ((nextPoint['latitude'] - point['latitude']).abs() < .000001 &&
            (nextPoint['longitude'] - point['longitude']).abs() < .000001)) {
      return;
    }
    setState(() => point = nextPoint);
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), fetch);
  }

  Future<void> fetch({bool more = false}) async {
    if (!mounted) return;
    request?.cancel();
    final token = request = CancelToken(), version = ++generation;
    final center = {...point};
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AppScope.of(context).api.places.fetch(
        latitude: center['latitude'],
        longitude: center['longitude'],
        query: '',
        language: language,
        page: more ? next : null,
        cancelToken: token,
      );
      if (!mounted || version != generation) return;
      setState(() {
        if (!more) places.clear();
        final ids = places.map((p) => p['id']).toSet();
        places.addAll(result.places.where((p) => ids.add(p['id'])));
        next = result.next;
      });
    } catch (e) {
      if (mounted && version == generation && !token.isCancelled) {
        setState(() => error = context.l10n.placesCouldNotBeLoaded);
      }
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }

  Future<void> search(String value) async {
    searchRequest?.cancel();
    final term = value.trim();
    final version = ++searchGeneration;
    setState(() {
      query = term;
      results.clear();
      searchError = null;
      searchLoading = term.isNotEmpty;
    });
    if (term.isEmpty) return;
    final token = searchRequest = CancelToken();
    try {
      final result = await AppScope.of(context).api.places.fetch(
        latitude: point['latitude'],
        longitude: point['longitude'],
        query: term,
        language: language,
        cancelToken: token,
      );
      if (!mounted || version != searchGeneration) return;
      setState(() => results.addAll(result.places));
    } catch (_) {
      if (mounted && version == searchGeneration && !token.isCancelled) {
        setState(() => searchError = context.l10n.placesCouldNotBeLoaded);
      }
    } finally {
      if (mounted && version == searchGeneration) {
        setState(() => searchLoading = false);
      }
    }
  }

  /// LocationPickerControllerNode.goToUserLocation: the back button drops
  /// the picked coordinate and returns to the user's position.
  void goToUserLocation() {
    animatePicking(false);
    final here = current;
    if (here == null) return;
    setState(() => point = {...here});
    map.flyTo(
      here['latitude'],
      here['longitude'],
      zoom: PlaceSearch.zoomForDelta(.02),
    );
    fetch();
  }

  void openSearch() {
    setState(() => searching = true);
    searchFocus.requestFocus();
  }

  void closeSearch() {
    searchRequest?.cancel();
    searchGeneration++;
    searchFocus.unfocus();
    searchInput.clear();
    setState(() {
      searching = false;
      query = '';
      results.clear();
      searchLoading = false;
      searchError = null;
    });
  }

  Future<void> locate({bool initial = false}) async {
    if (locating) return;
    setState(() => locating = true);
    try {
      final p = await currentPosition();
      if (!mounted) return;
      setState(() {
        current = {'latitude': p.latitude, 'longitude': p.longitude};
        point = {...current!};
      });
      await map.flyTo(
        p.latitude,
        p.longitude,
        zoom: PlaceSearch.zoomForDelta(.02),
      );
    } catch (e) {
      if (mounted && !initial) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.allowLocationAccessToUseYour)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => locating = false);
        await fetch();
      }
    }
  }

  void select(Json value) {
    final coordinate = coordinatesOf(value);
    if (coordinate == null) return;
    HapticFeedback.selectionClick();
    final name = string(value['name']), address = string(value['address']);
    Navigator.pop(context, {
      ...coordinate,
      'name': name.isEmpty ? context.l10n.selectedLocation : name,
      // `location[address]` is the only text the API stores: a venue keeps
      // Telegram's title + address as "Name, address" (venueTitle splits
      // it again); a plain coordinate sends the reserved label, which the
      // bubble never shows (locationHasVenue).
      'address': name.isEmpty
          ? address
          : [name, address].where((v) => v.isNotEmpty).join(', '),
      'delta': value['delta'] ?? .02,
    });
  }

  /// A plain coordinate: Telegram sends no venue for it.
  void sendPoint() => select({
    ...point,
    'address': widget.teleport
        ? addressLabel
        : atCurrent && !isPicking
        ? context.l10n.currentLocation
        : context.l10n.selectedLocation,
  });

  bool get atCurrent =>
      current != null &&
      (point['latitude'] - current!['latitude']).abs() < .00002 &&
      (point['longitude'] - current!['longitude']).abs() < .00002;

  String get coordinateLabel =>
      '${(point['latitude'] as num).toStringAsFixed(5)}, ${(point['longitude'] as num).toStringAsFixed(5)}';

  /// The nearest venue's address stands in for reverse geocoding.
  String get addressLabel {
    final nearest = places.where((p) => string(p['address']).isNotEmpty);
    return nearest.isEmpty ? coordinateLabel : string(nearest.first['address']);
  }

  String get sendTitle => widget.teleport
      ? context.l10n.teleportToThisArea
      : atCurrent && !isPicking
      ? context.l10n.sendMyCurrentLocation
      : context.l10n.sendSelectedLocation;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final reduced = media.disableAnimations;
    return Material(
      color: palette.row,
      child: LayoutBuilder(
        builder: (context, box) {
          final height = box.maxHeight, width = box.maxWidth;
          final top = media.padding.top;
          return AnimatedBuilder(
            animation: Listenable.merge([scroll, picking, lift]),
            builder: (context, _) {
              final p = picking.value;
              final offset = scroll.hasClients
                  ? scroll.offset.clamp(0.0, double.infinity)
                  : 0.0;
              final listTop = top + _Picker.topInset;
              final normalHeader = math.max(0.0, listTop - offset);
              final header = normalHeader + (height - normalHeader) * p;
              // The camera centre stays in the middle of the visible map.
              final mapTop = header / 2 - height / 2;
              final controlsAlpha = ((header - (top + 160)) / 40).clamp(
                0.0,
                1.0,
              );
              final sendInset = media.padding.bottom + _Picker.sendBottom;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: mapTop,
                    height: height,
                    child: GameMap(
                      controller: map,
                      latitude: point['latitude'],
                      longitude: point['longitude'],
                      zoom: PlaceSearch.zoomForDelta(.02),
                      pitch: 0,
                      bearing: 0,
                      controls: false,
                      onMove: moved,
                      onMoveStart: moveStarted,
                    ),
                  ),
                  // LocationPinAnnotationView: lifts 14pt while moving, its
                  // shadow stays on the coordinate.
                  Positioned(
                    left: width / 2 - 15,
                    top: header / 2 - 46,
                    child: IgnorePointer(
                      child: _LocationPin(lift: lift.value * 14),
                    ),
                  ),
                  // The list scrolls over the map; touches above its first
                  // row reach the map (ListView header passthrough).
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(0, (height - listTop + offset) * p),
                      child: _PassThroughAbove(
                        cutoff: math.max(0.0, listTop - offset),
                        child: _list(context, listTop),
                      ),
                    ),
                  ),
                  // Bottom EdgeEffectView: list colour at 0.65 over 88pt.
                  if (p < 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _Picker.bottomEdge + media.padding.bottom,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (1 - p).clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  palette.row.withValues(alpha: 0),
                                  palette.row.withValues(alpha: .65),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Map controls: a glass column at the header's trailing
                  // bottom, raised 94pt above the send button while picking.
                  PositionedDirectional(
                    end: _Picker.edge,
                    top:
                        header -
                        _Picker.button -
                        _Picker.edge -
                        94 * p -
                        (isPicking ? media.padding.bottom : 0),
                    child: Opacity(
                      opacity: isPicking ? 1 : controlsAlpha,
                      child: IgnorePointer(
                        ignoring: controlsAlpha == 0 && !isPicking,
                        child: AppIconButton(
                          glass: true,
                          symbolSize: 20,
                          color: atCurrent ? palette.accent : palette.text,
                          tooltip: context.l10n.myLocation,
                          icon: locating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator.adaptive(),
                                )
                              : Icon(
                                  atCurrent
                                      ? Icons.near_me
                                      : Icons.near_me_outlined,
                                  size: 20,
                                ),
                          onPressed: locating ? null : () => locate(),
                        ),
                      ),
                    ),
                  ),
                  // Glass close/back and search buttons, 16pt from the edges.
                  // topEdgeEffectView behind the title and bar buttons.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: top + _Picker.topEdge,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              palette.row.withValues(alpha: .65),
                              palette.row.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Map_ChooseLocationTitle: semibold 17, centred on the bar
                  // buttons' row.
                  Positioned(
                    left: _Picker.edge * 2 + _Picker.button,
                    right: _Picker.edge * 2 + _Picker.button,
                    top: top + _Picker.edge,
                    height: _Picker.button,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          widget.teleport
                              ? context.l10n.teleportToThisArea
                              : context.l10n.chooseLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: AppDesign.font(
                            17,
                            weight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: _Picker.edge,
                    top: top + _Picker.edge,
                    child: AppIconButton(
                      glass: true,
                      tooltip: isPicking
                          ? MaterialLocalizations.of(context).backButtonTooltip
                          : MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                      icon: Icon(
                        isPicking ? Icons.arrow_back_ios_new : Icons.close,
                        size: 20,
                      ),
                      onPressed: () {
                        if (searching) {
                          closeSearch();
                        } else if (isPicking) {
                          goToUserLocation();
                        } else {
                          Navigator.maybePop(context);
                        }
                      },
                    ),
                  ),
                  PositionedDirectional(
                    end: _Picker.edge,
                    top: top + _Picker.edge,
                    child: AnimatedScale(
                      scale: searching ? .01 : 1,
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 300),
                      child: AnimatedOpacity(
                        opacity: searching ? 0 : 1,
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        child: AppIconButton(
                          glass: true,
                          tooltip: context.l10n.searchPlaces,
                          icon: const Icon(Icons.search, size: 22),
                          onPressed: searching ? null : openSearch,
                        ),
                      ),
                    ),
                  ),
                  if (p > 0)
                    Positioned(
                      left: _Picker.sendSide,
                      right: _Picker.sendSide,
                      bottom: sendInset,
                      height: _Picker.sendHeight,
                      // ButtonComponent(.glass): accent glass, semibold 17
                      // title over a 13pt medium address at 0.7; it scales
                      // in from 0.01 with the layout spring.
                      child: Transform.scale(
                        scale: p.clamp(.01, 1.2),
                        child: Opacity(
                          opacity: p.clamp(0.0, 1.0),
                          child: AppPressable(
                            label: context.l10n.sendLocation,
                            style: AppPressStyle.glass,
                            onPressed: sendPoint,
                            child: GlassSurface(
                              radius: _Picker.sendHeight / 2,
                              tint: palette.accent,
                              interactive: true,
                              child: SizedBox.expand(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        widget.teleport
                                            ? sendTitle
                                            : context.l10n.sendLocation,
                                        maxLines: 1,
                                        textScaler: TextScaler.noScaling,
                                        style: AppDesign.font(
                                          17,
                                          weight: FontWeight.w600,
                                          color: palette.accentText,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        loading && places.isEmpty
                                            ? context.l10n.locating
                                            : addressLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textScaler: TextScaler.noScaling,
                                        style: AppDesign.font(
                                          13,
                                          weight: FontWeight.w500,
                                          color: palette.accentText.withValues(
                                            alpha: .7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (searching) _searchLayer(context),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _list(BuildContext context, double listTop) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    return ListView(
      controller: scroll,
      padding: EdgeInsets.only(top: listTop, bottom: media.padding.bottom + 24),
      children: [
        ColoredBox(
          color: palette.row,
          child: Column(
            children: [
              _LocationRow(
                height: _Picker.rowHeight,
                leading: _VenueIcon(color: palette.accent, icon: Icons.near_me),
                title: sendTitle,
                titleColor: palette.accent,
                subtitle: locating ? context.l10n.locating : addressLabel,
                onTap: sendPoint,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.l10n.nearbyPlaces,
                    style: AppDesign.font(13, color: palette.secondaryLabel),
                  ),
                ),
              ),
              ..._venues(context, places),
              if (loading || error != null || places.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ScreenStatus(
                    loading: loading,
                    error: error,
                    compact: true,
                    retry: error == null ? null : fetch,
                  ),
                ),
              if (next != null && !loading)
                AppButton.text(
                  onPressed: () => fetch(more: true),
                  child: Text(context.l10n.morePlaces),
                ),
              SizedBox(height: media.size.height * .4),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _venues(BuildContext context, List<Json> rows) => [
    for (var i = 0; i < rows.length; i++)
      _LocationRow(
        height: _Picker.venueHeight,
        separator: i < rows.length - 1,
        leading: _VenueIcon.forPlace(rows[i]),
        title: string(rows[i]['name']),
        subtitle: string(rows[i]['address']),
        onTap: () => select(rows[i]),
      ),
  ];

  /// LocationSearchContainerNode: results over the screen, the input in a
  /// glass capsule at the bottom above the keyboard.
  Widget _searchLayer(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    return Positioned.fill(
      child: ColoredBox(
        color: palette.row,
        child: Stack(
          children: [
            ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                top: media.padding.top + _Picker.edge * 2 + _Picker.button,
                bottom: keyboard + 80 + media.padding.bottom,
              ),
              children: [
                ..._venues(context, results),
                if (query.isNotEmpty &&
                    (searchLoading || searchError != null || results.isEmpty))
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: ScreenStatus(
                      loading: searchLoading,
                      error: searchError,
                      compact: true,
                      title: context.l10n.noPlacesFound,
                      retry: searchError == null ? null : () => search(query),
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: math.max(keyboard, media.padding.bottom) + 8,
              child: Row(
                children: [
                  Expanded(
                    child: GlassSurface(
                      radius: 22,
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              Icons.search,
                              size: 20,
                              color: palette.secondaryLabel,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: searchInput,
                                focusNode: searchFocus,
                                autocorrect: false,
                                textInputAction: TextInputAction.search,
                                cursorColor: palette.accent,
                                style: AppDesign.font(17, color: palette.text),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  hintText: context.l10n.searchPlaces2,
                                  hintStyle: AppDesign.font(
                                    17,
                                    color: palette.secondaryLabel,
                                  ),
                                ),
                                onChanged: (value) {
                                  debounce?.cancel();
                                  debounce = Timer(
                                    const Duration(milliseconds: 400),
                                    () => search(value),
                                  );
                                },
                                onSubmitted: search,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    glass: true,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: closeSearch,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hit-tests only below [cutoff] so the map behind the list stays draggable.
class _PassThroughAbove extends SingleChildRenderObjectWidget {
  final double cutoff;
  const _PassThroughAbove({required this.cutoff, super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPassThrough(cutoff);
  @override
  void updateRenderObject(BuildContext context, _RenderPassThrough render) =>
      render.cutoff = cutoff;
}

class _RenderPassThrough extends RenderProxyBox {
  double cutoff;
  _RenderPassThrough(this.cutoff);
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      position.dy >= cutoff && super.hitTest(result, position: position);
}

/// LocationActionListItem / venue item: 40pt icon at 16pt, 17pt title and a
/// 14pt secondary subtitle, hairline separators inset to the text.
class _LocationRow extends StatelessWidget {
  final double height;
  final Widget leading;
  final String title, subtitle;
  final Color? titleColor;
  final bool separator;
  final VoidCallback onTap;
  const _LocationRow({
    required this.height,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.separator = false,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppPressable(
      label: [title, subtitle].where((v) => v.isNotEmpty).join(', '),
      style: AppPressStyle.row,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Row(
          children: [
            const SizedBox(width: 16),
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                constraints: BoxConstraints(minHeight: height),
                padding: const EdgeInsetsDirectional.only(end: 16),
                decoration: BoxDecoration(
                  border: separator
                      ? Border(
                          bottom: BorderSide(
                            color: palette.border,
                            width: 1 / MediaQuery.devicePixelRatioOf(context),
                          ),
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesign.font(
                        17,
                        color: titleColor ?? palette.text,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppDesign.font(
                            14,
                            color: palette.secondaryLabel,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _VenueIcon({required this.color, required this.icon});

  factory _VenueIcon.forPlace(Json place) {
    final type = string(place['venue']);
    return _VenueIcon(
      color: AppDesign.venueColor(type, string(place['name'])),
      icon: place['kind'] == 'country'
          ? Icons.public
          : place['kind'] == 'region'
          ? Icons.location_city
          : venueGlyph(type),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    width: _Picker.icon,
    height: _Picker.icon,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, size: 22, color: Colors.white),
  );
}

/// Telegram's picking pin: an accent head with a white rim on a short stem,
/// raised by [lift] over its ground shadow while the camera moves.
class _LocationPin extends StatelessWidget {
  final double lift;
  const _LocationPin({this.lift = 0});
  @override
  Widget build(BuildContext context) {
    final accent = AppPalette.of(context).accent;
    return SizedBox(
      width: 30,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 1,
            child: Container(
              width: 10 + lift * .3,
              height: 5,
              decoration: BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, .25 - lift * .006),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -lift),
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: SizedBox.square(
                      dimension: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A Material stand-in for the Foursquare category glyph Telegram downloads.
IconData venueGlyph(String type) => switch (type.split('/').first) {
  'food' => Icons.restaurant,
  'nightlife' => Icons.local_bar,
  'travel' => type == 'travel' ? Icons.flight : Icons.hotel,
  'shops' => Icons.shopping_bag,
  'education' => Icons.school,
  'arts_entertainment' => Icons.theater_comedy,
  'parks_outdoors' => Icons.park,
  'work' => Icons.work,
  'building' =>
    type == 'building/medical'
        ? Icons.local_hospital
        : type == 'building/gym'
        ? Icons.fitness_center
        : Icons.location_city,
  _ => Icons.place,
};
