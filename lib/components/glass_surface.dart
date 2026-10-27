import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../design/app_design.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;

/// A frame of the map platform view, for glass drawn over it: the decoded
/// image and the render box it covers (read at paint time, so a map that
/// moves on screen stays aligned).
class PlatformSnapshot {
  final ui.Image image;
  final RenderBox box;
  const PlatformSnapshot(this.image, this.box);

  /// The map's rectangle in global (screen) coordinates, or null when the
  /// box is gone.
  Rect? get rect {
    if (!box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }
}

/// Whether a live platform view (the WebView map) is on screen, and the
/// latest frame of it. Flutter glass cannot sample platform-view pixels, so
/// GameMap sends its rendered frames ([snapshot]) and every glass control
/// over it paints the matching part under itself ([PlatformBackdropUnderlay])
/// and renders normally — the same renderer on iOS and Android. Until the
/// first frame arrives controls take the vendored BackdropFilter path
/// (`platformViewBackdrop`). GameMap registers itself while its tab/route
/// is active.
abstract final class PlatformBackdrop {
  static final _owners = <Object>{};
  static final ValueNotifier<int> visible = ValueNotifier(0);
  static final ValueNotifier<PlatformSnapshot?> snapshot = ValueNotifier(null);
  static Object? _snapshotOwner;
  static bool get active => _owners.isNotEmpty;

  /// Marks [owner] as showing (or no longer showing) a platform view.
  /// Idempotent per owner, so it cannot drift.
  static void set(Object owner, bool showing) {
    final changed = showing ? _owners.add(owner) : _owners.remove(owner);
    if (!showing) publish(owner, null);
    if (changed) visible.value = _owners.length;
  }

  /// Replaces the frame with [owner]'s; null withdraws [owner]'s frame. The
  /// previous image is released after the next frame, when no painter still
  /// holds it.
  static void publish(Object owner, PlatformSnapshot? next) {
    if (next == null && !identical(_snapshotOwner, owner)) return;
    final previous = snapshot.value;
    _snapshotOwner = next == null ? null : owner;
    snapshot.value = next;
    if (previous != null && !identical(previous.image, next?.image)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => previous.image.dispose(),
      );
    }
  }

  /// Rebuilds [builder] when the state changes. `active` is true only while
  /// glass must fall back: a platform view is visible and none of its frames
  /// has arrived yet.
  static Widget listen(
    Widget Function(BuildContext context, bool active) builder,
  ) => ListenableBuilder(
    listenable: Listenable.merge([visible, snapshot]),
    builder: (context, _) =>
        builder(context, visible.value > 0 && snapshot.value == null),
  );
}

/// Paints the map frame under [child] where it overlaps the map, clipped to
/// [shape] grown by [bleed] (room for the rim refraction to sample). Nothing
/// is painted when no frame exists or the child is not over the map, so it
/// wraps every glass control unconditionally. The copy lies exactly over the
/// live map, so only the glass's refraction of it shows.
class PlatformBackdropUnderlay extends SingleChildRenderObjectWidget {
  final ShapeBorder shape;
  final double bleed;
  const PlatformBackdropUnderlay({
    super.key,
    required this.shape,
    this.bleed = 2,
    super.child,
  });
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPlatformBackdropUnderlay(shape, bleed);
  @override
  void updateRenderObject(
    BuildContext context,
    RenderPlatformBackdropUnderlay renderObject,
  ) => renderObject
    ..shape = shape
    ..bleed = bleed;
}

class RenderPlatformBackdropUnderlay extends RenderProxyBox {
  ShapeBorder _shape;
  double _bleed;
  RenderPlatformBackdropUnderlay(this._shape, this._bleed);
  set shape(ShapeBorder value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsPaint();
  }

  set bleed(double value) {
    if (value == _bleed) return;
    _bleed = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    PlatformBackdrop.snapshot.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    PlatformBackdrop.snapshot.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final frame = PlatformBackdrop.snapshot.value;
    final map = frame?.rect;
    if (frame != null && map != null && !map.isEmpty && hasSize) {
      final local = (Offset.zero & size).inflate(_bleed);
      final toGlobal = getTransformTo(null);
      final toLocal = Matrix4.tryInvert(toGlobal);
      final global = MatrixUtils.transformRect(toGlobal, local);
      final covered = global.intersect(map);
      if (toLocal != null && !covered.isEmpty) {
        final image = frame.image;
        final sx = image.width / map.width, sy = image.height / map.height;
        final canvas = context.canvas
          ..save()
          ..clipPath(_shape.getOuterPath(local.shift(offset)));
        canvas
          ..drawImageRect(
            image,
            Rect.fromLTRB(
              (covered.left - map.left) * sx,
              (covered.top - map.top) * sy,
              (covered.right - map.left) * sx,
              (covered.bottom - map.top) * sy,
            ),
            MatrixUtils.transformRect(toLocal, covered).shift(offset),
            Paint()..filterQuality = FilterQuality.medium,
          )
          ..restore();
      }
    }
    super.paint(context, offset);
  }
}

enum GlassSurfaceRole {
  control,
  input,
  menu,
  sheet;

  // The composer is persistent floating chrome, like its header and buttons.
  // Minimal is a blur-only material: it must not disable the input's optics.
  liquid.GlassQuality get quality => this == sheet || this == menu
      ? liquid.GlassQuality.minimal
      : liquid.GlassQuality.premium;
}

/// One material definition for fields, surfaces and interactive controls.
/// An explicit tint is composited directly so the chosen accent is preserved.
liquid.LiquidGlassSettings appGlassSettings(
  BuildContext context, {
  Color? tint,
  bool clear = false,
  bool platformViewBackdrop = false,
  GlassSurfaceRole role = GlassSurfaceRole.control,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final input = role == GlassSurfaceRole.input;
  if (role != GlassSurfaceRole.control) {
    return liquid.LiquidGlassSettings(
      glassColor:
          tint ??
          (role == GlassSurfaceRole.menu
              ? dark
                    ? AppDesign.glassMenuDark
                    : AppDesign.glassMenuLight
              : dark
              ? AppDesign.glassFrostedDark
              : role == GlassSurfaceRole.sheet
              ? AppDesign.glassSheetLight
              : AppDesign.glassInputLight),
      blur: AppDesign.glassSurfaceBlur,
      saturation: 1,
      // Keep the white blur body in both Impeller and the standard renderer;
      // the input also needs the optical rim used by its adjacent controls.
      thickness: input ? AppDesign.glassThickness : 0,
      lightIntensity: input ? AppDesign.glassLightIntensity : 0,
      fresnelStrength: input ? AppDesign.glassFresnelStrength : 0,
      chromaticAberration: 0,
      standardOpacityMultiplier: 1,
      bodyMode: liquid.GlassBodyMode.clear,
      shadow: dark ? const [] : AppDesign.glassShadow,
    );
  }
  return liquid.LiquidGlassSettings(
    glassColor:
        tint ??
        (clear
            ? (dark ? AppDesign.glassClearDark : Colors.transparent)
            : (dark ? AppDesign.glassPanelDark : AppDesign.glassPanelLight)),
    // The shader's separate frost pass cannot sample a platform view. Use
    // that same frost radius in the live backdrop, retaining the light tint.
    blur: clear
        ? AppDesign.glassClearBlur
        : platformViewBackdrop
        ? AppDesign.glassFrost
        : AppDesign.glassBlur,
    thickness: AppDesign.glassThickness,
    frost: clear || tint != null ? 0 : AppDesign.glassFrost,
    frostOpacity: dark ? .7 : .6,
    frostClamp: dark ? -.4 : .3,
    saturation: 1.2,
    refractiveIndex: 1.2,
    standardOpacityMultiplier: 2,
    chromaticAberration: 0,
    lightIntensity: AppDesign.glassLightIntensity,
    fresnelStrength: AppDesign.glassFresnelStrength,
    shadow: dark ? const [] : AppDesign.glassShadow,
    bodyMode: clear || tint != null
        ? liquid.GlassBodyMode.clear
        : liquid.GlassBodyMode.adaptive,
  );
}

/// Modals share the same white frosted material as input surfaces.
liquid.LiquidGlassSettings sheetGlass(BuildContext context, {Color? tint}) =>
    appGlassSettings(context, role: GlassSurfaceRole.sheet, tint: tint);

/// The application's single glass surface, backed by the vendored renderer.
/// Gestures remain owned by AppPressable; nested controls share this material.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? tint;
  final GlassSurfaceRole role;
  final bool clear, interactive, hostsScrolling, circular;
  final bool useOwnLayer;
  final bool topOnly;
  final VoidCallback? onPressed;
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.tint,
    this.clear = false,
    this.role = GlassSurfaceRole.control,
    this.interactive = false,
    this.hostsScrolling = false,
    this.circular = false,
    this.useOwnLayer = false,
    this.topOnly = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => PlatformBackdrop.listen(
    (context, overPlatformView) => _build(context, overPlatformView),
  );

  Widget _build(BuildContext context, bool overPlatformView) {
    final settings = appGlassSettings(
      context,
      tint: tint,
      clear: clear,
      role: role,
      platformViewBackdrop: overPlatformView,
    );
    final liquid.LiquidShape shape = circular
        ? const liquid.LiquidOval()
        : topOnly
        ? liquid.LiquidVerticalRoundedSuperellipse(
            topRadius: radius,
            bottomRadius: 0,
          )
        : liquid.LiquidRoundedSuperellipse(borderRadius: radius);
    final Widget surface = PlatformBackdropUnderlay(
      shape: circular
          ? const CircleBorder()
          : RoundedSuperellipseBorder(
              borderRadius: topOnly
                  ? BorderRadius.vertical(top: Radius.circular(radius))
                  : BorderRadius.circular(radius),
            ),
      child: liquid.GlassContainer(
        useOwnLayer: useOwnLayer,
        platformViewBackdrop: overPlatformView,
        shape: shape,
        quality: role.quality,
        clipBehavior: Clip.antiAlias,
        settings: !circular && radius == 0
            ? settings.copyWith(lightIntensity: 0, fresnelStrength: 0)
            : settings,
        child: interactive
            ? liquid.GlassGlow(
                enabled:
                    !MediaQuery.disableAnimationsOf(context) &&
                    !MediaQuery.highContrastOf(context),
                clipper: ShapeBorderClipper(shape: shape),
                glowRadius: 1.6,
                glowBlurRadius: 16,
                glowOnTapOnly: true,
                child: child,
              )
            : child,
      ),
    );
    return onPressed == null
        ? surface
        : Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: surface,
            ),
          );
  }
}

/// The one backdrop blur (source BackdropBlur / expo-blur): a Flutter blur
/// at [intensity] with [tint] drawn above it, identical on every platform.
class AppBackdropBlur extends StatelessWidget {
  final double intensity;
  final bool dark;
  final Color? tint;
  final double radius;
  final Widget? child;
  const AppBackdropBlur({
    super.key,
    required this.intensity,
    required this.dark,
    this.tint,
    this.radius = 0,
    this.child,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: liquid.GlassAccessibilityData.of(context).reduceTransparency
              ? ColoredBox(color: dark ? const Color(0xff1c1c1e) : Colors.white)
              : BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: intensity / 4,
                    sigmaY: intensity / 4,
                  ),
                  child: const SizedBox.expand(),
                ),
        ),
        if (tint != null) Positioned.fill(child: ColoredBox(color: tint!)),
        ?child,
      ],
    ),
  );
}
