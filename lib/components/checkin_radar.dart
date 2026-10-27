import '../l10n/l10n.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/mobile_spring.dart';
import '../core/radar_geometry.dart';
import '../design/app_design.dart';
import 'components.dart';
import 'glass_surface.dart';

List<Json> checkInTags(BuildContext context) {
  final data = AppScope.of(context).system;
  final raw = object(data['data']).isNotEmpty ? object(data['data']) : data;
  return (raw['checkin_tag_types'] as List? ?? [])
      .map(object)
      .where((t) => t['is_visible'] != false && string(t['tag']).isNotEmpty)
      .toList();
}

String checkInTagLabel(BuildContext context, String tag) {
  final item = checkInTags(context).where((t) => t['tag'] == tag).firstOrNull;
  return plainText(
    item?['name'] ?? tag,
    language: Localizations.localeOf(context).languageCode,
  );
}

class _TagArtwork {
  final Json glyphs;
  final List<Json> gradients;
  const _TagArtwork(this.glyphs, this.gradients);
  static final cache = Expando<Future<_TagArtwork>>();
  static Future<_TagArtwork> load(AssetBundle bundle) =>
      cache[bundle] ??= () async {
        final values = await Future.wait([
          bundle.loadString('assets/data/material-community-icons.json'),
          bundle.loadString('assets/data/tag-gradients.json'),
        ]);
        return _TagArtwork(
          object(jsonDecode(values[0])),
          (jsonDecode(values[1]) as List).map(object).toList(),
        );
      }();
  static Color color(dynamic value) =>
      Color(int.parse(string(value).replaceFirst('#', 'ff'), radix: 16));
  static Json gradient(List<Json> gradients, String tag) {
    if (gradients.isEmpty) return {};
    var seed = 0;
    for (final code in tag.codeUnits) {
      seed = ((seed << 5) - seed + code).toSigned(32);
    }
    return gradients[seed.abs() % gradients.length];
  }
}

class _TagGlyph extends StatelessWidget {
  final dynamic code;
  final double size;
  final Color color;
  const _TagGlyph(this.code, this.size, this.color);
  @override
  Widget build(BuildContext context) => code is num
      ? Text(
          String.fromCharCode((code as num).toInt()),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'MaterialCommunityIcons',
            fontSize: size,
            color: color,
          ),
        )
      : Icon(Icons.local_offer_outlined, size: size, color: color);
}

/// Source ChatInput tag attachment: 80pt gradient tile, 20pt glyph, 10pt label.
class CheckInTagPreview extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;
  const CheckInTagPreview({
    super.key,
    required this.tag,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<_TagArtwork>(
    future: _TagArtwork.load(DefaultAssetBundle.of(context)),
    builder: (context, snapshot) {
      final art = snapshot.data,
          data =
              checkInTags(context).where((t) => t['tag'] == tag).firstOrNull ??
              <String, dynamic>{};
      final gradient = _TagArtwork.gradient(art?.gradients ?? [], tag);
      final foreground = gradient.isEmpty
          ? Theme.of(context).colorScheme.onSurface
          : _TagArtwork.color(gradient['textColor']);
      final name = checkInTagLabel(context, tag);
      return SizedBox.square(
        dimension: 80,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GlassSurface(
                radius: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: gradient.isEmpty
                        ? null
                        : LinearGradient(
                            colors: (gradient['colors'] as List)
                                .map(_TagArtwork.color)
                                .toList(),
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TagGlyph(
                        art?.glyphs[string(data['icon'])],
                        20,
                        foreground,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppDesign.font(10, color: foreground),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -5,
              right: -5,
              child: AppPressable(
                label: context.l10n.removeTag(name),
                onPressed: onRemove,
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  alignment: Alignment.center,
                  child: GlassSurface(
                    radius: 11,
                    tint: const Color(0x8c000000),
                    child: const SizedBox.square(
                      dimension: 22,
                      child: Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// CheckInBar/index.tsx: 100pt hex spacing, 156pt cells, 76pt tag buttons.
class CheckInRadar extends StatefulWidget {
  final Set<String> selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;
  const CheckInRadar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });
  @override
  State<CheckInRadar> createState() => _CheckInRadarState();
}

class _CheckInRadarState extends State<CheckInRadar>
    with TickerProviderStateMixin {
  late final AnimationController x, y;
  @override
  void initState() {
    super.initState();
    x = AnimationController.unbounded(vsync: this);
    y = AnimationController.unbounded(vsync: this);
  }

  Offset origin = Offset.zero, start = Offset.zero;
  Json glyphs = {};
  List<Json> gradients = [];
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      load();
    }
  }

  Future<void> load() async {
    final art = await _TagArtwork.load(DefaultAssetBundle.of(context));
    if (mounted) {
      setState(() {
        glyphs = art.glyphs;
        gradients = art.gradients;
      });
    }
  }

  void snap(
    Offset target,
    Offset velocity, {
    double stiffness = 90,
    double damping = 18,
  }) {
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
        damping: damping,
      ),
    );
    y.animateWith(
      MobileSpring(
        y.value,
        target.dy,
        velocity.dy + y.velocity,
        stiffness: stiffness,
        damping: damping,
      ),
    );
  }

  @override
  void dispose() {
    x.dispose();
    y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = checkInTags(context),
        cells = RadarGeometry.spiral()
            .take(checkInTags(context).length)
            .map((c) => RadarGeometry.position(c.$1, c.$2))
            .toList();
    if (tags.isEmpty) {
      return ScreenStatus(
        compact: true,
        retry: AppScope.of(context).syncSystem,
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        double clamp(double value, double min, double max) =>
            min > max ? value : value.clamp(min, max);
        final center = Offset(
          clamp(
            box.maxWidth / 2,
            34 - cells.map((p) => p.dx - 78).reduce(math.min),
            box.maxWidth - 34 - cells.map((p) => p.dx + 78).reduce(math.max),
          ),
          clamp(
            box.maxHeight / 2 - 24,
            34 - cells.map((p) => p.dy - 78).reduce(math.min),
            box.maxHeight - 34 - cells.map((p) => p.dy + 78).reduce(math.max),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (e) {
                  x.stop();
                  y.stop();
                  origin = e.localPosition;
                  start = Offset(x.value, y.value);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (e) {
                    final d = e.localPosition - origin;
                    x.value = start.dx + d.dx;
                    y.value = start.dy + d.dy;
                  },
                  onPanEnd: (e) {
                    final predicted =
                        Offset(x.value, y.value) +
                        e.velocity.pixelsPerSecond * .1;
                    final closest = cells.reduce(
                      (a, b) =>
                          (a + predicted).distanceSquared <
                              (b + predicted).distanceSquared
                          ? a
                          : b,
                    );
                    snap(-closest, e.velocity.pixelsPerSecond);
                  },
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([x, y]),
                      builder: (context, _) {
                        final pan = Offset(x.value, y.value),
                            order = List.generate(tags.length, (i) => i)
                              ..sort(
                                (a, b) => (cells[b] + pan).distance.compareTo(
                                  (cells[a] + pan).distance,
                                ),
                              );
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _TagRings(
                                  center,
                                  AppPalette.of(context).border,
                                ),
                              ),
                            ),
                            for (final i in order)
                              Positioned(
                                key: ValueKey(tags[i]['tag']),
                                left: center.dx + cells[i].dx + pan.dx - 78,
                                top: center.dy + cells[i].dy + pan.dy - 78,
                                width: 156,
                                height: 156,
                                child: _CheckInTag(
                                  tag: tags[i],
                                  selected: widget.selected.contains(
                                    tags[i]['tag'],
                                  ),
                                  distance: (cells[i] + pan).distance,
                                  glyphs: glyphs,
                                  gradients: gradients,
                                  onPressed: () {
                                    snap(
                                      -cells[i],
                                      Offset.zero,
                                      stiffness: 100,
                                      damping: 20,
                                    );
                                    HapticFeedback.mediumImpact();
                                    widget.onSelect(string(tags[i]['tag']));
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    context.l10n.dragToSelect,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ),
              ),
            ),
            if (widget.selected.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: GlassSurface(
                    radius: 20,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.selected.length} ${context.l10n.vibeSelected}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          AppButton.text(
                            onPressed: widget.onClear,
                            child: Text(
                              context.l10n.reset,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CheckInTag extends StatefulWidget {
  final Json tag, glyphs;
  final List<Json> gradients;
  final bool selected;
  final double distance;
  final VoidCallback onPressed;
  const _CheckInTag({
    required this.tag,
    required this.glyphs,
    required this.gradients,
    required this.selected,
    required this.distance,
    required this.onPressed,
  });
  @override
  State<_CheckInTag> createState() => _CheckInTagState();
}

class _CheckInTagState extends State<_CheckInTag>
    with SingleTickerProviderStateMixin {
  double target(double distance) => distance <= 80
      ? 1.5 - .5 * distance / 80
      : 1 - .32 * ((distance - 80) / 340).clamp(0, 1);
  late final scale = AnimationController.unbounded(
    vsync: this,
    value: target(widget.distance),
  );
  @override
  void didUpdateWidget(_CheckInTag old) {
    super.didUpdateWidget(old);
    if (old.distance != widget.distance) {
      if (MediaQuery.disableAnimationsOf(context)) {
        scale.value = target(widget.distance);
      } else {
        scale.animateWith(
          MobileSpring(
            scale.value,
            target(widget.distance),
            scale.velocity,
            stiffness: 90,
            damping: 20,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _TagArtwork.gradient(
      widget.gradients,
      string(widget.tag['tag']),
    );
    Color color(dynamic value) => _TagArtwork.color(value);
    final opacity = widget.distance <= 260
        ? 1 - .08 * widget.distance / 260
        : .92 - .24 * ((widget.distance - 260) / 220).clamp(0, 1);
    final label = checkInTagLabel(context, string(widget.tag['tag']));
    final glyph = widget.glyphs[string(widget.tag['icon'])];
    final foreground = widget.selected && gradient.isNotEmpty
        ? color(gradient['textColor'])
        : Theme.of(context).colorScheme.onSurface;
    final image = _TagGlyph(glyph, widget.selected ? 34 : 28, foreground);
    return AnimatedBuilder(
      animation: scale,
      builder: (context, _) => Transform.scale(
        scale: scale.value,
        child: Stack(
          children: [
            Positioned(
              left: 40,
              top: 40,
              width: 76,
              height: 76,
              child: GlassSurface(
                radius: 38,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.selected && gradient.isNotEmpty
                        ? LinearGradient(
                            colors: (gradient['colors'] as List)
                                .map(color)
                                .toList(),
                          )
                        : null,
                    border: Border.all(
                      width: 1.5,
                      color: widget.selected
                          ? Colors.transparent
                          : AppPalette.of(context).border,
                    ),
                  ),
                  child: AppPressable(
                    label: label,
                    selected: widget.selected,
                    style: AppPressStyle.tag,
                    onPressed: widget.onPressed,
                    child: Center(
                      child: Opacity(opacity: opacity, child: image),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 125,
              left: 4,
              right: 4,
              child: Opacity(
                opacity: opacity,
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppDesign.fontFamily,
                    fontSize: 9.5,
                    height: 13 / 9.5,
                    letterSpacing: .25,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagRings extends CustomPainter {
  final Offset center;
  final Color color;
  const _TagRings(this.center, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    for (final (radius, opacity) in [(70.0, 1.0), (150.0, .5), (230.0, .2)]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: color.a * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_TagRings old) =>
      old.center != center || old.color != color;
}
