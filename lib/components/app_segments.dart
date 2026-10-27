import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_button.dart';
import '../vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'glass_surface.dart';
import '../design/app_design.dart';

class AppSegments<T extends Object> extends StatefulWidget {
  final Map<T, Widget> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool header;
  final bool contentSized;
  final double? fontSize;
  const AppSegments({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.header = false,
    this.contentSized = false,
    this.fontSize,
  });
  static double heightFor(BuildContext context, {bool header = false}) => header
      ? AppDesign.minimumTarget
      : (MediaQuery.textScalerOf(context).scale(17) + 24).clamp(
          AppDesign.minimumTarget,
          double.infinity,
        );

  @override
  State<AppSegments<T>> createState() => _AppSegmentsState<T>();
}

class _AppSegmentsState<T extends Object> extends State<AppSegments<T>> {
  String labelOf(Widget value) {
    if (value is Tooltip) return value.message ?? labelOf(value.child!);
    if (value is Semantics) {
      return value.properties.label ??
          (value.child == null ? '' : labelOf(value.child!));
    }
    if (value is GestureDetector) {
      return value.child == null ? '' : labelOf(value.child!);
    }
    if (value is Text) return value.data ?? '';
    return '';
  }

  /// The visible content: an Icon becomes its Cupertino glyph, so every
  /// platform shows the same symbol.
  Widget contentOf(Widget value) {
    if (value is Tooltip) return contentOf(value.child!);
    if (value is Semantics && value.child != null) {
      return contentOf(value.child!);
    }
    if (value is GestureDetector && value.child != null) {
      return contentOf(value.child!);
    }
    if (value is Icon) {
      final symbol = AppIconButton.symbols[value.icon?.codePoint];
      final glyph = symbol == null ? null : AppSymbol.icons[symbol];
      if (glyph != null) return Icon(glyph, size: value.size ?? 20);
    }
    return value;
  }

  void choose(int index) {
    if (!mounted || index < 0 || index >= widget.values.length) return;
    final entry = widget.values.entries.elementAt(index);
    if (entry.key == widget.selected) {
      final child = entry.value;
      if (child is GestureDetector) child.onTap?.call();
    } else {
      HapticFeedback.selectionClick();
      widget.onChanged(entry.key);
    }
  }

  Offset? downAt;
  Duration? downTime;

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final fitted = widget.contentSized;
    final textScaler = MediaQuery.textScalerOf(context);
    final fontSize =
        widget.fontSize ?? (fitted ? AppDesign.mediaTabsFontSize : 13.0);
    final height = fitted
        ? (textScaler.scale(fontSize) - fontSize + AppDesign.mediaTabsHeight)
                  .clamp(AppDesign.mediaTabsHeight, double.infinity) +
              4
        : AppSegments.heightFor(context, header: widget.header);
    final entries = widget.values.entries.toList();
    final selected = entries.indexWhere((e) => e.key == widget.selected);
    final labelStyle = AppDesign.font(
      fontSize,
      weight: fitted ? FontWeight.w500 : FontWeight.w600,
      color: palette.text,
    );
    const labelInset =
        AppDesign.mediaTabsTextInset - AppDesign.mediaTabsOverlap / 2;
    const edgeInset = AppDesign.mediaTabsOverlap / 2;
    var naturalWidth = edgeInset * 2;
    for (final entry in entries) {
      final painter = TextPainter(
        text: TextSpan(text: labelOf(entry.value), style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      naturalWidth += painter.width + labelInset * 2;
      painter.dispose();
    }
    final control = PlatformBackdrop.listen(
      (context, overPlatformView) => liquid.InheritedLiquidGlass(
        settings: appGlassSettings(context),
        quality: overPlatformView
            ? liquid.GlassQuality.minimal
            : liquid.GlassQuality.premium,
        child: PlatformBackdropUnderlay(
          shape: const StadiumBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: GlassSurface(
                    radius: 9999,
                    useOwnLayer: true,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              liquid.GlassSegmentedControl(
                quality: overPlatformView
                    ? liquid.GlassQuality.minimal
                    : liquid.GlassQuality.premium,
                settings: appGlassSettings(context),
                backgroundColor: Colors.transparent,
                isScrollable: fitted || entries.length == 1,
                dragBehavior: fitted
                    ? liquid.SegmentDragBehavior.selectOnRelease
                    : liquid.SegmentDragBehavior.selectIndicator,
                padding: fitted
                    ? const EdgeInsets.symmetric(
                        horizontal: edgeInset,
                        vertical: AppDesign.mediaTabsLensInset,
                      )
                    : const EdgeInsets.all(3),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: labelInset,
                ),
                indicatorHorizontalOutset: fitted
                    ? edgeInset - AppDesign.mediaTabsLensInset
                    : 0,
                indicatorExpansion: const EdgeInsets.all(
                  AppDesign.mediaTabsLensInset + AppDesign.mediaTabsLiftedInset,
                ),
                indicatorColor: AppDesign.mediaTabsSelectionColor(context),
                indicatorSettings: liquid
                    .AnimatedGlassIndicator
                    .baseIndicatorSettings
                    .copyWith(
                      shadow: Theme.of(context).brightness == Brightness.dark
                          ? const []
                          : AppDesign.glassShadow,
                    ),
                segments: [
                  for (final e in entries)
                    contentOf(e.value) is Icon
                        ? liquid.GlassSegment(
                            icon: contentOf(e.value),
                            semanticLabel: labelOf(e.value),
                            tooltip: labelOf(e.value),
                          )
                        : liquid.GlassSegment(
                            label: labelOf(e.value),
                            semanticLabel: labelOf(e.value),
                          ),
                ],
                selectedIndex: selected < 0 ? 0 : selected,
                onSegmentSelected: choose,
                height: widget.header || fitted ? height - 4 : height,
                iconSize: 20,
                selectedIconColor: palette.text,
                unselectedIconColor: palette.secondaryLabel,
                selectedTextStyle: labelStyle,
                unselectedTextStyle: fitted
                    ? labelStyle
                    : AppDesign.font(fontSize, color: palette.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
    // A second tap on the selected segment runs its own action (the grid
    // segment opens the column menu); the control only reports changes.
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: fitted ? naturalWidth.clamp(0, constraints.maxWidth) : null,
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: widget.header || fitted ? 2 : 0,
          ),
          child: LayoutBuilder(
            builder: (context, box) => Listener(
              onPointerDown: (e) {
                if (fitted) return;
                downAt = e.localPosition;
                downTime = e.timeStamp;
              },
              onPointerUp: (e) {
                final start = downAt, at = downTime;
                downAt = null;
                if (start == null ||
                    at == null ||
                    (e.localPosition - start).distance > 10 ||
                    e.timeStamp - at > const Duration(milliseconds: 400)) {
                  return;
                }
                final physical =
                    (e.localPosition.dx / (box.maxWidth / entries.length))
                        .floor()
                        .clamp(0, entries.length - 1);
                final index = Directionality.of(context) == TextDirection.rtl
                    ? entries.length - 1 - physical
                    : physical;
                if (index == selected) choose(index);
              },
              child: control,
            ),
          ),
        ),
      ),
    );
  }
}

/// Telegram ChatListFilterTabContainerNode (source NativeFolderTabs): one
/// floating 44pt glass capsule, 16pt side margins, a scrolling strip with a
/// 36pt highlight pill that springs behind the selected 14pt title.
class AppFolderTabs<T> extends StatefulWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const AppFolderTabs({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });
  @override
  State<AppFolderTabs<T>> createState() => _AppFolderTabsState<T>();
}

class _AppFolderTabsState<T> extends State<AppFolderTabs<T>> {
  final keys = <Object?, GlobalKey>{};
  final strip = GlobalKey();
  Rect? pill;

  void measure() {
    final box =
        keys[widget.value]?.currentContext?.findRenderObject() as RenderBox?;
    final parent = strip.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || parent == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero, ancestor: parent) & box.size;
    if (rect != pill) setState(() => pill = rect);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) measure();
    });
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GlassSurface(
        radius: 22,
        child: SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Stack(
              key: strip,
              children: [
                if (pill != null)
                  AnimatedPositioned(
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    left: pill!.left,
                    width: pill!.width,
                    top: 4,
                    bottom: 4,
                    child: const GlassSurface(
                      radius: 18,
                      clear: true,
                      interactive: true,
                      child: SizedBox.expand(),
                    ),
                  ),
                Row(
                  children: [
                    for (final (key, label) in widget.items)
                      Semantics(
                        selected: key == widget.value,
                        button: true,
                        label: label,
                        child: GestureDetector(
                          key: keys.putIfAbsent(key, GlobalKey.new),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (key != widget.value) {
                              HapticFeedback.selectionClick();
                              widget.onChanged(key);
                            }
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: AppDesign.font(
                                14,
                                weight: key == widget.value
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: key == widget.value
                                    ? palette.text
                                    : palette.secondaryLabel,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
