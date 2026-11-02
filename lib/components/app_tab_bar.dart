import 'glass_surface.dart';
import 'illustrated_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;

/// The icon-only bottom tab bar on the vendored Liquid Glass GlassTabBar,
/// whose lens follows a drag and springs onto the tab; identical on iOS and
/// Android.
class AppTabBar extends StatelessWidget {
  static const height = 64.0;
  static const _iconSize = 48.0;

  /// Room around the bar for the pressed lens, which grows past the bar by
  /// the indicator expansion; without it the lens is cut off and the shader
  /// samples nothing (black bands above and below).
  ///
  /// Vertical only: the vendor's horizontal padding does not inset the bar,
  /// and a wider lens shows the neighbouring tab's icons under it.
  static const _room = EdgeInsets.symmetric(vertical: 8);

  /// TabBarControllerNode side insets: 12pt, or 20pt when the bottom safe
  /// inset is 28pt or less (no home indicator). The bar sits 14pt into the
  /// home-indicator area, at least 8pt above the screen edge.
  static EdgeInsets insets(BuildContext context) {
    // UITabBar lays out its own floating margins and home-indicator inset.
    if (native) return EdgeInsets.zero;
    final media = MediaQuery.of(context);
    final safe = media.viewPadding.bottom;
    final side = safe <= 28 ? 20.0 : 12.0;
    final bottom = safe - 14 < 8 ? 8.0 : safe - 14;
    // The widget carries [_room] itself; the visible bar keeps these insets.
    return EdgeInsets.fromLTRB(
      side + media.viewPadding.left - _room.left,
      0,
      side + media.viewPadding.right - _room.right,
      bottom - _room.bottom,
    );
  }

  /// iOS: the system UITabBar (AGENTS: system tabs use UITabBar), whose
  /// Liquid Glass and selection lens refract the real backdrop — the map
  /// included. Elsewhere the vendored Flutter bar below.
  static bool get native =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// SF Symbols used if a native catalog image cannot load.
  static const _symbols = [
    ('house', 'house.fill'),
    ('location.circle', 'location.circle.fill'),
    ('antenna.radiowaves.left.and.right', 'antenna.radiowaves.left.and.right'),
    ('mappin.and.ellipse', 'mappin.and.ellipse'),
    ('bubble.left.and.bubble.right', 'bubble.left.and.bubble.right.fill'),
  ];

  /// The vendored Flutter bar hosts these directly as [IllustratedIcon]s;
  /// NativeTabBarView.swift reads matching bundled asset-catalog images.
  static const _illustrated = [
    'interest-funny-films',
    'system-users',
    'bubbles',
    'eye-color',
    'messagecircleheart',
  ];

  /// ios/Runner/Assets.xcassets/tab_*.imageset — same order as [_illustrated].
  static const _illustratedAssets = [
    'tab_home',
    'tab_nearby',
    'tab_bubbles',
    'tab_eyecolor',
    'tab_messagecircleheart',
  ];

  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelected;
  const AppTabBar({
    super.key,
    required this.selected,
    required this.labels,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (native) {
      return _NativeTabBar(
        selected: selected,
        labels: labels,
        onSelected: onSelected,
      );
    }
    final palette = AppPalette.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return PlatformBackdrop.listen(
      (context, overPlatformView) => SizedBox(
        height: height + _room.vertical,
        // A live backdrop filter can sample the map's platform layer. The
        // indicator separately captures the Flutter icons for its moving lens;
        // neither needs an opaque backplate hiding the map.
        child: liquid.GlassTabBar.bottom(
          platformViewBackdrop: overPlatformView,
          // clear: true + an explicit premium quality match the honeycomb
          // bubbles/chat button: without both, GlassTabBar falls back to
          // GlassQuality.standard (no ancestor InheritedLiquidGlass here)
          // and the opaque frosted-panel tint, so the bar read noticeably
          // more solid than the rest of the app's clear glass chrome.
          settings: appGlassSettings(
            context,
            clear: true,
            platformViewBackdrop: overPlatformView,
          ),
          quality: GlassSurfaceRole.control.quality,
          backgroundQuality: GlassSurfaceRole.control.quality,
          // Over the map the lens refracts only the captured icon layer;
          // where that capture is empty it takes the lens fill, not black.
          indicatorSettings: overPlatformView
              ? liquid.LiquidGlassSettings(
                  platformViewFallbackColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? AppDesign.glassLensFallbackDark
                      : AppDesign.glassLensFallbackLight,
                )
              : null,
          tabs: [
            for (var i = 0; i < labels.length; i++)
              liquid.GlassTab(
                icon: Opacity(
                  opacity: .55,
                  child: IllustratedIcon(_illustrated[i], size: _iconSize),
                ),
                activeIcon: IllustratedIcon(_illustrated[i], size: _iconSize),
                label: null,
                semanticLabel: labels[i],
              ),
          ],
          selectedIndex: selected,
          onTabSelected: onSelected,
          // The lens grows into [_room]; the shell insets do the rest.
          horizontalPadding: _room.left,
          verticalPadding: _room.top,
          indicatorExpansion: _room,
          barHeight: height,
          iconSize: _iconSize,
          selectedIconColor: accent,
          unselectedIconColor: palette.text,
        ),
      ),
    );
  }
}

/// The `coolvibes/tabbar` platform view (ios/Runner/NativeTabBarView.swift).
class _NativeTabBar extends StatefulWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelected;
  const _NativeTabBar({
    required this.selected,
    required this.labels,
    required this.onSelected,
  });
  @override
  State<_NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<_NativeTabBar> {
  MethodChannel? channel;
  double? height;
  Map<String, Object?>? sent;

  Map<String, Object?> params(BuildContext context) {
    final palette = AppPalette.of(context);
    return {
      // Keep localized labels available to VoiceOver while rendering the
      // UITabBar items as icon-only tabs.
      'titles': List<String>.filled(widget.labels.length, ''),
      'accessibilityLabels': widget.labels,
      'symbols': [for (final s in AppTabBar._symbols) s.$1],
      'selectedSymbols': [for (final s in AppTabBar._symbols) s.$2],
      'illustrated': AppTabBar._illustratedAssets,
      'selected': widget.selected,
      'tint': Theme.of(context).colorScheme.primary.toARGB32(),
      'unselected': palette.text.toARGB32(),
      'dark': Theme.of(context).brightness == Brightness.dark,
      'rtl': Directionality.of(context) == TextDirection.rtl,
    };
  }

  void push(Map<String, Object?> next) {
    final channel = this.channel;
    if (channel == null || mapEquals(sent, next)) return;
    sent = next;
    channel.invokeMethod('update', next);
  }

  Future<void> handle(MethodCall call) async {
    if (!mounted) return;
    switch (call.method) {
      case 'select':
        HapticFeedback.selectionClick();
        widget.onSelected(call.arguments as int);
      case 'height':
        final value = (call.arguments as num).toDouble();
        if (value != height) setState(() => height = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = params(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) push(current);
    });
    // Until UITabBar reports its fitted height: Telegram's 64pt bar over the
    // home-indicator inset.
    final fallback =
        AppTabBar.height + MediaQuery.viewPaddingOf(context).bottom - 14;
    return SizedBox(
      height: height ?? fallback,
      child: Offstage(
        offstage: ModalRoute.isCurrentOf(context) == false,
        child: UiKitView(
          viewType: 'coolvibes/tabbar',
          creationParams: current,
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          onPlatformViewCreated: (id) {
            channel = MethodChannel('coolvibes/tabbar_$id')
              ..setMethodCallHandler(handle);
            sent = current;
          },
        ),
      ),
    );
  }
}
