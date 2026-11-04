import '../l10n/l10n.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/mobile_spring.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../components/components.dart';
import '../components/chat_wallpaper.dart';
import '../components/glass_surface.dart';
import '../design/app_design.dart';
import '../components/workspace_menu.dart';
import '../components/radar_group_card.dart';
import '../components/living_background.dart';
import '../core/api.dart';
import '../core/app_failure.dart';
import '../core/chat_data.dart';
import '../core/radar_geometry.dart';
import '../core/session.dart';
import 'discover.dart';
import 'settings.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});
  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with TickerProviderStateMixin {
  late final x = AnimationController.unbounded(vsync: this),
      y = AnimationController.unbounded(vsync: this),
      zoom = AnimationController.unbounded(vsync: this, value: 1);
  late final motion = RadarMotion(this);
  final groups = <Json>[], positions = <Offset>[];
  final seen = <String>{};
  Json? selected, activeGroup;
  String? cursor, error;
  bool loading = false, loaded = false, started = false;
  Offset startPan = Offset.zero, pointerOrigin = Offset.zero;
  Timer? hold;
  bool panning = false;
  Size viewport = Size.zero;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started && TickerMode.valuesOf(context).enabled) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fetch();
      });
    }
  }

  Future<void> fetch({bool reset = false}) async {
    if (loading) return;
    final api = AppScope.of(context).api;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        groups.clear();
        positions.clear();
        seen.clear();
        cursor = null;
      }
    });
    try {
      final language = AppScope.of(context).locale.languageCode;
      final response = await api.call(
        'chat.group.list',
        body: {if (cursor != null) 'cursor': cursor, 'limit': 30},
      );
      final page = RecordPage.parse(response);
      if (!mounted) return;
      setState(() {
        for (final raw in page.records) {
          final group = groupRadarRecord(raw, language: language);
          if (recordId(group).isNotEmpty && seen.add(recordId(group))) {
            groups.add(group);
          }
        }
        final cells = RadarGeometry.spiral().take(groups.length).toList();
        positions
          ..clear()
          ..addAll(
            cells.map((cell) => RadarGeometry.position(cell.$1, cell.$2)),
          );
        cursor = page.next;
        loaded = true;
        activeGroup ??= nearestGroup(Offset(x.value, y.value));
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = AppFailure.from(e).message(context.l10n));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void animatePan(Offset target, Offset velocity, {double stiffness = 90}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      x.value = target.dx;
      y.value = target.dy;
      return;
    }
    x.animateWith(
      MobileSpring(
        x.value,
        target.dx,
        velocity.dx + x.velocity,
        stiffness: stiffness,
        damping: 18,
      ),
    );
    y.animateWith(
      MobileSpring(
        y.value,
        target.dy,
        velocity.dy + y.velocity,
        stiffness: stiffness,
        damping: 18,
      ),
    );
  }

  void zoomTo(double target, {bool returning = false}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      zoom.value = target;
    } else {
      zoom.animateWith(
        MobileSpring(
          zoom.value,
          target,
          zoom.velocity,
          stiffness: returning ? 900 : 150,
          damping: returning ? 120 : 20,
        ),
      );
    }
  }

  void openGroup(int index) {
    hold?.cancel();
    animatePan(-positions[index], Offset.zero, stiffness: 100);
    HapticFeedback.mediumImpact();
    setState(() {
      selected = groups[index];
      activeGroup = groups[index];
    });
  }

  /// The group nearest a given pan offset — used to update [activeGroup] at
  /// discrete moments (load, tap, settle) rather than live every pan frame.
  /// A continuously recomputed value fed a keyed AnimatedSwitcher flickers
  /// between neighbors while dragging, which crashed with "Duplicate keys
  /// found" as the switcher tried to re-enter a key mid-transition.
  Json? nearestGroup(Offset pan) {
    if (positions.isEmpty) return null;
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < positions.length && i < groups.length; i++) {
      final distance = (positions[i] + pan).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return groups[bestIndex];
  }

  @override
  void dispose() {
    hold?.cancel();
    x.dispose();
    y.dispose();
    zoom.dispose();
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome =
        MediaQuery.viewPaddingOf(context).top + AppDesign.headerInset(context);
    return AppScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppHeader(
        edge: selected == null ? AppHeaderEdge.none : AppHeaderEdge.soft,
        leading: selected == null
            ? const WorkspaceMenuButton()
            : ClipOval(
                child: SizedBox.square(
                  dimension: 40,
                  child: Avatar(selected!, radius: 20),
                ),
              ),
        title: selected == null ? null : Text(personName(selected!)),
        actions: selected == null
            ? [
                AppIconButton(
                  dimension: 44,
                  tooltip: context.l10n.search,
                  icon: const Icon(Icons.search),
                  onPressed: () => open(context, const SearchScreen()),
                ),
                AppIconButton(
                  dimension: 44,
                  tooltip: context.l10n.activity,
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => open(context, const ActivityScreen()),
                ),
              ]
            : [
                AppIconButton(
                  dimension: 44,
                  tooltip: context.l10n.close,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => setState(() => selected = null),
                ),
              ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          // Match/index.tsx: the honeycomb centres on the canvas minus the
          // transparent header band; iOS native tabs add no overlay inset.
          viewport = box.biggest;
          // Measured against the iOS reference capture of the source radar.
          final center = Offset(
            box.maxWidth / 2,
            (box.maxHeight -
                    View.of(context).viewPadding.bottom /
                        View.of(context).devicePixelRatio +
                    chrome) /
                2,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: _RadarWallpaper(
                  group: activeGroup,
                  motion: motion,
                  pan: Listenable.merge([x, y]),
                  panOffset: () => Offset(x.value, y.value) * .06,
                ),
              ),
              Positioned.fill(
                child: Listener(
                  onPointerDown: (event) {
                    // Gesture.Pan().onBegin: remember the pan at touch down;
                    // a running spring keeps going until the pan activates.
                    startPan = Offset(x.value, y.value);
                    pointerOrigin = event.localPosition;
                    hold?.cancel();
                    if (!onBubble(event.localPosition, center)) {
                      // Gesture.LongPress().minDuration(200), maxDist 10.
                      hold = Timer(const Duration(milliseconds: 200), () {
                        if (mounted) zoomTo(.5);
                      });
                    }
                  },
                  onPointerMove: (event) {
                    if ((event.localPosition - pointerOrigin).distance > 10) {
                      hold?.cancel();
                    }
                  },
                  onPointerUp: (_) => release(),
                  onPointerCancel: (_) => release(),
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      PanGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            PanGestureRecognizer
                          >(
                            () => PanGestureRecognizer(supportedDevices: null),
                            (recognizer) => recognizer
                              // UIPanGestureRecognizer hysteresis (~10pt).
                              ..gestureSettings = const DeviceGestureSettings(
                                touchSlop: 5,
                              )
                              ..dragStartBehavior = DragStartBehavior.down
                              ..onStart = (_) {
                                panning = true;
                              }
                              ..onUpdate = (event) {
                                if (x.isAnimating) x.stop();
                                if (y.isAnimating) y.stop();
                                x.value =
                                    startPan.dx +
                                    event.localPosition.dx -
                                    pointerOrigin.dx;
                                y.value =
                                    startPan.dy +
                                    event.localPosition.dy -
                                    pointerOrigin.dy;
                              }
                              ..onEnd = (event) {
                                panning = false;
                                settle(event.velocity.pixelsPerSecond);
                              }
                              ..onCancel = () => panning = false,
                          ),
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge([x, y, zoom]),
                      // zoomScale shrinks each bubble individually instead
                      // of wrapping the whole canvas in Transform.scale:
                      // that used to shrink the canvas's own clip bounds
                      // along with it, so the grid read as a small floating
                      // "window" instead of pulling back within the full
                      // screen. The backdrop grid/crosshair stay full-size.
                      builder: (context, _) => _RadarCanvas(
                        groups: groups,
                        positions: positions,
                        pan: Offset(x.value, y.value),
                        center: center,
                        size: box.biggest,
                        accent: AppPalette.of(context).accent,
                        text: AppPalette.of(context).text,
                        motion: motion,
                        zoomScale: zoom.value,
                        onSelect: openGroup,
                      ),
                    ),
                  ),
                ),
              ),
              if (loading && groups.isEmpty)
                const Center(child: CircularProgressIndicator.adaptive()),
              if (error != null && groups.isEmpty)
                Center(
                  child: ScreenStatus(error: error, retry: () => fetch()),
                ),
              if (loaded && groups.isEmpty && error == null)
                const Center(child: ScreenStatus()),
              if (selected != null)
                Positioned.fill(
                  child: RadarGroupCard(
                    key: ValueKey(recordId(selected!)),
                    group: selected!,
                    motion: motion,
                    topInset: chrome,
                    onClose: () => setState(() => selected = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  bool onBubble(Offset point, Offset center) {
    final pan = Offset(x.value, y.value);
    for (final position in positions) {
      final distance = (position + pan).distance;
      if ((position + pan + center - point).distance <
          45 * RadarGeometry.scale(distance)) {
        return true;
      }
    }
    return false;
  }

  void release() {
    hold?.cancel();
    // LongPress onEnd/onFinalize: withSpring(1) with the default config.
    if (zoom.value != 1 || zoom.isAnimating) zoomTo(1, returning: true);
  }

  /// Pan onEnd: spring to the honeycomb cell nearest the predicted position
  /// and load the next page only when the view nears the grid edge.
  void settle(Offset velocity) {
    if (positions.isEmpty) return;
    final target = RadarGeometry.nearest(
      positions,
      Offset(x.value, y.value),
      velocity,
    );
    animatePan(target, velocity);
    // Where the spring will land, not the live drag position — settling
    // once here (instead of live every frame) is what avoids the rapid
    // key-flicker crash in _RadarWallpaper's AnimatedSwitcher.
    final next = nearestGroup(target);
    if (next != null && recordId(next) != recordId(activeGroup ?? const {})) {
      setState(() => activeGroup = next);
    }
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in positions) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    const threshold = 200.0;
    final cx = -target.dx, cy = -target.dy;
    if (cursor != null &&
        !loading &&
        (cx + viewport.width / 2 >= maxX - threshold ||
            cx - viewport.width / 2 <= minX + threshold ||
            cy + viewport.height / 2 >= maxY - threshold ||
            cy - viewport.height / 2 <= minY + threshold)) {
      fetch();
    }
  }
}

/// The default textured wallpaper, or — once a group is centered — that
/// group's hero photo (sharp, just dimmed) drifting slowly behind the
/// honeycomb so the backdrop reads as alive rather than a static photo.
class _RadarWallpaper extends StatelessWidget {
  final Json? group;
  final RadarMotion motion;
  final Listenable pan;
  final Offset Function() panOffset;
  const _RadarWallpaper({
    required this.group,
    required this.motion,
    required this.pan,
    required this.panOffset,
  });
  @override
  Widget build(BuildContext context) => FlashFreeCrossFade(
    child: group == null
        ? const ChatWallpaper(key: ValueKey('radar.wallpaper.default'))
        : Stack(
            key: ValueKey('radar.wallpaper.${recordId(group!)}'),
            fit: StackFit.expand,
            children: [
              DriftingImage(
                motion: motion,
                // More overscan than the default — clamped against this by
                // DriftingImage itself, but a bigger budget means the pan
                // parallax actually has room to move before it clamps.
                scale: 1.3,
                extra: pan,
                extraOffset: panOffset,
                child: AppImage(
                  source: group!['localHeroAsset'] != null
                      ? AssetImage('${group!['localHeroAsset']}')
                      : (group!['hero'] ?? group!['cover']),
                  fit: BoxFit.cover,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      (Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white)
                          .withValues(alpha: .25),
                ),
              ),
            ],
          ),
  );
}

/// The honeycomb, backdrop and fixed crosshair of Match/index.tsx.
class _RadarCanvas extends StatelessWidget {
  final List<Json> groups;
  final List<Offset> positions;
  final Offset pan, center;
  final Size size;
  final Color accent, text;
  final RadarMotion motion;
  final double zoomScale;
  final ValueChanged<int> onSelect;
  const _RadarCanvas({
    required this.groups,
    required this.positions,
    required this.pan,
    required this.center,
    required this.size,
    required this.accent,
    required this.text,
    required this.motion,
    required this.zoomScale,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    // Culling and zIndex = round(1000 - dist): nearer bubbles paint on top.
    final visible =
        <int>[
          for (var i = 0; i < positions.length && i < groups.length; i++)
            if (() {
              final point = positions[i] + pan + center;
              return point.dx > -RadarGeometry.itemSize &&
                  point.dx < size.width + RadarGeometry.itemSize &&
                  point.dy > -RadarGeometry.itemSize &&
                  point.dy < size.height + RadarGeometry.itemSize;
            }())
              i,
        ]..sort(
          (a, b) => (positions[b] + pan).distance.compareTo(
            (positions[a] + pan).distance,
          ),
        );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _RadarBackdrop(center: center, accent: accent),
            ),
          ),
        ),
        for (final i in visible)
          Positioned(
            key: ValueKey(recordId(groups[i])),
            left:
                positions[i].dx +
                pan.dx +
                center.dx -
                RadarGeometry.itemSize / 2,
            top:
                positions[i].dy +
                pan.dy +
                center.dy -
                RadarGeometry.itemSize / 2,
            width: RadarGeometry.itemSize,
            height: RadarGeometry.itemSize,
            child: Transform.scale(
              scale:
                  RadarGeometry.scale((positions[i] + pan).distance) *
                  zoomScale,
              child: _RadarBubble(
                group: groups[i],
                opacity: RadarGeometry.opacity((positions[i] + pan).distance),
                onTap: () => onSelect(i),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RadarCrosshair(center: center, color: text),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarBubble extends StatelessWidget {
  final Json group;
  final double opacity;
  final VoidCallback onTap;
  const _RadarBubble({
    required this.group,
    required this.opacity,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 45,
    clear: true,
    interactive: true,
    child: AppPressable(
      label: personName(group),
      style: AppPressStyle.radar,
      onPressed: onTap,
      child: SizedBox.square(
        dimension: 90,
        child: Center(
          child: Opacity(
            opacity: opacity,
            // Circular to match the glass bubble around it; a rounded
            // square here reads as a mistake against the round surface.
            // Static (not drift-animated like the background): this cell is
            // rebuilt from scratch every pan frame since bubbles reorder and
            // cull as you drag, which made a live-motion subscription here
            // churn its listener every frame and crash the element tree.
            child: Avatar(group, radius: 39, glass: false),
          ),
        ),
      ),
    ),
  );
}

class _RadarBackdrop extends CustomPainter {
  final Offset center;
  final Color accent;
  const _RadarBackdrop({required this.center, required this.accent});
  @override
  void paint(Canvas canvas, Size size) {
    // RadarBackdrop: four 1040pt grid lines and a 120pt glow. The three
    // concentric ring circles used to live here too, but they stacked up
    // into a messy layered-circle look (worse once the canvas is scaled
    // for the long-press zoom), so they're gone.
    for (final (angle, opacity) in [
      (0.0, .06),
      (math.pi / 2, .06),
      (math.pi / 4, .03),
      (-math.pi / 4, .03),
    ]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawRect(
        const Rect.fromLTWH(-520, -.5, 1040, 1),
        Paint()..color = accent.withValues(alpha: opacity),
      );
      canvas.restore();
    }
    canvas.drawCircle(
      center,
      60,
      Paint()..color = accent.withValues(alpha: .04),
    );
  }

  @override
  bool shouldRepaint(_RadarBackdrop old) =>
      center != old.center || accent != old.accent;
}

/// The fixed crosshair (magnet point) drawn above the bubbles.
class _RadarCrosshair extends CustomPainter {
  final Offset center;
  final Color color;
  const _RadarCrosshair({required this.center, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = color.withValues(alpha: .1);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 1, height: 60),
      line,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 60, height: 1),
      line,
    );
  }

  @override
  bool shouldRepaint(_RadarCrosshair old) =>
      center != old.center || color != old.color;
}
