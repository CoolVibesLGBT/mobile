import '../l10n/l10n.dart';
import '../core/geo.dart';
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
import '../components/radar_profile_card.dart';
import '../core/api.dart';
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
  final users = <Json>[], positions = <Offset>[];
  final seen = <String>{};
  Json? selected;
  Json coordinates = {'latitude': 41.0082, 'longitude': 28.9784};
  String? cursor, error;
  bool loading = false, loaded = false, started = false;
  Offset startPan = Offset.zero, pointerOrigin = Offset.zero;
  Timer? hold;
  bool panning = false;
  Size viewport = Size.zero;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started && TickerMode.of(context)) {
      started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fetch(locate: !AppScope.of(context).api.isPreview);
      });
    }
  }

  Future<void> fetch({bool reset = false, bool locate = false}) async {
    if (loading) return;
    final api = AppScope.of(context).api;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        users.clear();
        positions.clear();
        seen.clear();
        cursor = null;
      }
    });
    try {
      if (locate) {
        try {
          final p = await currentPosition();
          coordinates = {'latitude': p.latitude, 'longitude': p.longitude};
        } catch (_) {
          // The source also falls back to Istanbul when location is unavailable.
        }
        if (!mounted) return;
      }
      final response = await api.call(
        'user.fetch.nearby.users',
        body: {
          ...coordinates,
          if (cursor != null) 'cursor': cursor,
          'limit': 60,
        },
      );
      final page = RecordPage.parse(response);
      if (!mounted) return;
      setState(() {
        for (final user in page.records) {
          if (recordId(user).isNotEmpty &&
              seen.add(recordId(user)) &&
              user['is_blocked'] != true) {
            users.add(nearbyPerson(user, coordinates));
          }
        }
        final cells = RadarGeometry.spiral().take(users.length).toList();
        positions
          ..clear()
          ..addAll(
            cells.map((cell) => RadarGeometry.position(cell.$1, cell.$2)),
          );
        cursor = page.next;
        loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
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

  void focus(int index) {
    hold?.cancel();
    animatePan(-positions[index], Offset.zero, stiffness: 100);
    HapticFeedback.mediumImpact();
    setState(() => selected = users[index]);
  }

  @override
  void dispose() {
    hold?.cancel();
    x.dispose();
    y.dispose();
    zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome =
        MediaQuery.viewPaddingOf(context).top + AppDesign.headerHeight;
    return AppScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppHeader(
        edge: selected == null ? AppHeaderEdge.none : AppHeaderEdge.soft,
        leading: const WorkspaceMenuButton(),
        actions: [
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
              const Positioned.fill(child: ChatWallpaper()),
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
                      builder: (context, _) => Transform.scale(
                        scale: zoom.value,
                        alignment: Alignment.center,
                        child: _RadarCanvas(
                          users: users,
                          positions: positions,
                          pan: Offset(x.value, y.value),
                          center: center,
                          size: box.biggest,
                          accent: AppPalette.of(context).accent,
                          text: AppPalette.of(context).text,
                          onSelect: focus,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (loading && users.isEmpty)
                const Center(child: CircularProgressIndicator.adaptive()),
              if (error != null && users.isEmpty)
                Center(
                  child: ScreenStatus(error: error, retry: () => fetch()),
                ),
              if (loaded && users.isEmpty && error == null)
                const Center(child: ScreenStatus()),
              if (selected != null)
                Positioned.fill(
                  child: RadarProfileCard(
                    key: ValueKey(recordId(selected!)),
                    user: selected!,
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

/// The honeycomb, backdrop and fixed crosshair of Match/index.tsx.
class _RadarCanvas extends StatelessWidget {
  final List<Json> users;
  final List<Offset> positions;
  final Offset pan, center;
  final Size size;
  final Color accent, text;
  final ValueChanged<int> onSelect;
  const _RadarCanvas({
    required this.users,
    required this.positions,
    required this.pan,
    required this.center,
    required this.size,
    required this.accent,
    required this.text,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    // Culling and zIndex = round(1000 - dist): nearer bubbles paint on top.
    final visible =
        <int>[
          for (var i = 0; i < positions.length && i < users.length; i++)
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
            key: ValueKey(recordId(users[i])),
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
              scale: RadarGeometry.scale((positions[i] + pan).distance),
              child: _RadarBubble(
                user: users[i],
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
  final Json user;
  final double opacity;
  final VoidCallback onTap;
  const _RadarBubble({
    required this.user,
    required this.opacity,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 45,
    clear: true,
    interactive: true,
    child: AppPressable(
      label: personName(user),
      style: AppPressStyle.radar,
      onPressed: onTap,
      child: SizedBox.square(
        dimension: 90,
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(user, radius: 39, glass: false),
                if (user['online'] == true || user['is_online'] == true)
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xff34c759),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
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
    // RadarBackdrop: four 1040pt grid lines, three rings and a 120pt glow.
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
    for (final (diameter, opacity) in [
      (220.0, .08),
      (420.0, .06),
      (640.0, .045),
    ]) {
      canvas.drawCircle(
        center,
        diameter / 2 - .5,
        Paint()
          ..color = Colors.black.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
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
    canvas.drawCircle(
      center,
      159.5,
      Paint()
        ..color = color.withValues(alpha: .03)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_RadarCrosshair old) =>
      center != old.center || color != old.color;
}
