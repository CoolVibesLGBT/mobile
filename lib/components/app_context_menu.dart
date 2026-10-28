import '../l10n/l10n.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/session.dart';
import '../design/app_design.dart';
import 'app_button.dart';
import 'glass_surface.dart';

/// One action of [AppContextMenu] (Telegram ContextMenuActionItem).
class AppMenuItem {
  final String title;
  final VoidCallback? onPressed;
  final List<AppMenuItem>? children;
  final TextStyle? textStyle;
  final bool keepOpen;
  final bool destructive;
  final bool? checked;
  final String? symbol;
  final String? iconAsset;
  final IconData? fallback;

  /// Telegram `.separator` before this action (e.g. before "Select").
  final bool separatorBefore;
  const AppMenuItem({
    required this.title,
    this.onPressed,
    this.children,
    this.textStyle,
    this.keepOpen = false,
    this.destructive = false,
    this.checked,
    this.symbol,
    this.iconAsset,
    this.fallback,
    this.separatorBefore = false,
  }) : assert(onPressed != null || children != null);
}

enum AppMenuAlign { auto, left, right, center }

/// Telegram ContextController metrics (ContextControllerActionsStackNode,
/// ContextControllerExtractedPresentationNode, ContextGesture).
abstract final class _Menu {
  /// ContextGesture.beginDelay, then a 0.2s activation progress.
  static const beginDelay = Duration(milliseconds: 120);
  static const activation = Duration(milliseconds: 200);
  static const minWidth = 220.0, maxWidth = 240.0;
  static const sideInset = 18.0, iconSideInset = 20.0, iconSlot = 32.0;
  static const titleX = iconSideInset + 40.0;
  static const verticalInset = 11.0, listInset = 10.0;
  static const separatorHeight = 20.0;
  static const contentSpacing = 7.0, edgeInset = 12.0;

  /// ContextControllerExtractedPresentationNode, `.controller` source: the
  /// previewed screen is 12pt from both edges, at most 460pt tall, never
  /// squeezed under 200pt, 10pt above the actions, corner radius 30.
  static const previewMaxHeight = 460.0, previewMinHeight = 200.0;
  static const previewSpacing = 10.0, previewBottomInset = 10.0;
  static const previewTopInset = 8.0, previewCorner = 30.0;

  /// animateSpring: mass 5, stiffness 900, damping 104 (settling duration).
  static final spring = SpringDescription(
    mass: 5,
    stiffness: 900,
    damping: 104,
  );
  static const dismiss = Duration(milliseconds: 200);
}

/// Marks a screen hosted as a context-menu preview (Telegram
/// `.standard(.previewing)`): it implies no back/close control, and its glass
/// is drawn by Flutter so it follows the preview's clip and scale.
class AppPreviewScope extends InheritedWidget {
  const AppPreviewScope({super.key, required super.child});
  static bool contains(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppPreviewScope>() != null;
  @override
  bool updateShouldNotify(AppPreviewScope oldWidget) => false;
}

/// The one long-press / pull-down menu, modelled on Telegram-iOS
/// ContextController: after 120ms the content shrinks for 200ms to
/// max(0.7, (w-15)/w), then lifts above a dimmed backdrop and the glass action
/// list springs out of the content edge. The finger may slide onto an action
/// and release to choose it.
class AppContextMenu extends StatefulWidget {
  final List<AppMenuItem> items;
  final Widget child;

  /// A previewed screen (Telegram's `.controller` content source). The menu
  /// owns its size and position; callers only supply the screen.
  final WidgetBuilder? previewBuilder;
  final String? title, label;
  final VoidCallback? onPressed;
  final bool pressTrigger, liftContent;
  final AppMenuAlign align;
  final double? previewRadius;
  final BoxDecoration? previewDecoration;

  /// False disables the long press (e.g. while messages are being selected).
  final bool enabled;
  const AppContextMenu({
    super.key,
    required this.items,
    required this.child,
    this.previewBuilder,
    this.title,
    this.label,
    this.onPressed,
    this.pressTrigger = false,
    this.liftContent = true,
    this.align = AppMenuAlign.auto,
    this.previewRadius,
    this.previewDecoration,
    this.enabled = true,
  });

  @override
  State<AppContextMenu> createState() => AppContextMenuState();
}

class AppContextMenuState extends State<AppContextMenu>
    with SingleTickerProviderStateMixin {
  final anchor = GlobalKey();
  bool lifted = false, menuOpen = false;
  int gestureGeneration = 0;
  late final press = AnimationController(
    vsync: this,
    duration: _Menu.activation,
  );
  Timer? delay;

  /// Pointer position while the opening press is still down.
  final _drag = ValueNotifier<Offset?>(null);
  _ContextMenuLayerState? _layer;

  double get _minScale {
    final box = anchor.currentContext?.findRenderObject() as RenderBox?;
    final side = box?.hasSize == true ? box!.size.width : 0.0;
    return side <= 15 ? 1 : math.max(.7, (side - 15) / side);
  }

  double get _scale => 1 - (1 - _minScale) * press.value;

  @override
  void dispose() {
    delay?.cancel();
    press.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _down() {
    if (menuOpen || MediaQuery.disableAnimationsOf(context)) return;
    delay?.cancel();
    delay = Timer(_Menu.beginDelay, () {
      if (mounted && !menuOpen) press.forward(from: 0);
    });
  }

  void _release() {
    delay?.cancel();
    if (!menuOpen && press.value > 0) {
      press.animateBack(0, duration: _Menu.activation, curve: Curves.easeOut);
    }
  }

  void open() {
    delay?.cancel();
    if (menuOpen) return;
    final box = anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || widget.items.isEmpty) {
      press.value = 0;
      return;
    }
    final session = AppScope.of(context);
    final token = session.api.token;
    AppMenuItem guard(AppMenuItem item) => AppMenuItem(
      title: item.title,
      symbol: item.symbol,
      iconAsset: item.iconAsset,
      fallback: item.fallback,
      checked: item.checked,
      destructive: item.destructive,
      separatorBefore: item.separatorBefore,
      textStyle: item.textStyle,
      keepOpen: item.keepOpen,
      children: item.children?.map(guard).toList(),
      onPressed: () {
        if (mounted && session.api.token == token) item.onPressed?.call();
      },
    );
    final guardedItems = widget.items.map(guard).toList();
    HapticFeedback.mediumImpact();
    final frame = box.localToGlobal(Offset.zero) & box.size;
    final fromScale = widget.previewBuilder == null ? _scale : 1.0;
    setState(() {
      menuOpen = true;
      lifted = widget.liftContent && widget.previewBuilder == null;
    });
    press.value = 0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Navigator.of(context, rootNavigator: true)
        .push(
          _ContextMenuRoute(
            frame: frame,
            fromScale: fromScale,
            onPreviewPressed: widget.onPressed == null
                ? null
                : () {
                    if (mounted && session.api.token == token) {
                      widget.onPressed!();
                    }
                  },
            screenPreview: widget.previewBuilder != null,
            items: guardedItems,
            title: widget.title,
            align: widget.align,
            rtl: rtl,
            drag: _drag,
            attach: (layer) => _layer = layer,
            preview: widget.previewBuilder != null
                ? MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_Menu.previewCorner),
                      child: AppPreviewScope(
                        child: Builder(builder: widget.previewBuilder!),
                      ),
                    ),
                  )
                : widget.liftContent
                ? Container(
                    decoration: widget.previewDecoration,
                    clipBehavior: widget.previewRadius == null
                        ? Clip.none
                        : Clip.antiAlias,
                    child: widget.previewRadius == null
                        ? widget.child
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(
                              widget.previewRadius!,
                            ),
                            child: widget.child,
                          ),
                  )
                : null,
            capturedThemes: InheritedTheme.capture(
              from: context,
              to: Navigator.of(context, rootNavigator: true).context,
            ),
            scope: AppScope.of(context),
          ),
        )
        .whenComplete(() {
          _layer = null;
          _drag.value = null;
          if (mounted) {
            setState(() {
              lifted = false;
              menuOpen = false;
              gestureGeneration++;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final longPress = widget.enabled && !widget.pressTrigger;
    return Semantics(
      button: true,
      label: widget.label,
      customSemanticsActions: widget.enabled
          ? {CustomSemanticsAction(label: context.l10n.actions): open}
          : null,
      child: RawGestureDetector(
        key: ValueKey(gestureGeneration),
        behavior: HitTestBehavior.opaque,
        gestures: {
          if (!menuOpen &&
              (widget.pressTrigger ? widget.enabled : widget.onPressed != null))
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (r) =>
                      r.onTap = widget.pressTrigger ? open : widget.onPressed,
                ),
          if (longPress)
            // ContextGesture: 0.12s delay + 0.2s activation progress.
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(
                    duration: _Menu.beginDelay + _Menu.activation,
                  ),
                  (r) => r
                    ..onLongPressDown = ((_) => _down())
                    ..onLongPressCancel = _release
                    ..onLongPress = open
                    ..onLongPressMoveUpdate = (details) {
                      if (menuOpen) _drag.value = details.globalPosition;
                    }
                    ..onLongPressEnd = (details) {
                      if (menuOpen) _layer?.release(details.globalPosition);
                      _drag.value = null;
                    },
                ),
        },
        child: KeyedSubtree(
          key: anchor,
          child: AnimatedBuilder(
            animation: press,
            builder: (context, child) => Transform.scale(
              scale: press.value == 0 ? 1 : _scale,
              child: child,
            ),
            // The lifted copy replaces the original while the menu is open.
            child: Opacity(opacity: lifted ? 0 : 1, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _ContextMenuRoute extends PopupRoute<void> {
  final Rect frame;
  final double fromScale;
  final VoidCallback? onPreviewPressed;
  final bool screenPreview;
  final List<AppMenuItem> items;
  final String? title;
  final AppMenuAlign align;
  final bool rtl;
  final Widget? preview;
  final CapturedThemes capturedThemes;
  final Session scope;
  final ValueNotifier<Offset?> drag;
  final ValueChanged<_ContextMenuLayerState?> attach;
  _ContextMenuRoute({
    required this.frame,
    required this.fromScale,
    required this.onPreviewPressed,
    required this.screenPreview,
    required this.items,
    required this.title,
    required this.align,
    required this.rtl,
    required this.preview,
    required this.capturedThemes,
    required this.scope,
    required this.drag,
    required this.attach,
  });

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel =>
      MaterialLocalizations.of(navigator!.context).modalBarrierDismissLabel;
  @override
  Duration get transitionDuration => _Menu.dismiss;
  @override
  Duration get reverseTransitionDuration => _Menu.dismiss;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => capturedThemes.wrap(
    AppScope(
      session: scope,
      child: _ContextMenuLayer(
        animation: animation,
        frame: frame,
        fromScale: fromScale,
        onPreviewPressed: onPreviewPressed == null
            ? null
            : () {
                if (!isCurrent) return;
                Navigator.of(context).pop();
                completed.then((_) => onPreviewPressed!());
              },
        screenPreview: screenPreview,
        items: items,
        title: title,
        align: align,
        rtl: rtl,
        preview: preview,
        drag: drag,
        attach: attach,
        close: () {
          if (isCurrent) Navigator.of(context).pop();
        },
      ),
    ),
  );
}

/// One entry of the action stack: an action or a Telegram separator.
class _Entry {
  final AppMenuItem? item;
  const _Entry(this.item);
  bool get separator => item == null;
}

class _ContextMenuLayer extends StatefulWidget {
  final Animation<double> animation;
  final Rect frame;
  final double fromScale;
  final VoidCallback? onPreviewPressed;
  final bool screenPreview;
  final List<AppMenuItem> items;
  final String? title;
  final AppMenuAlign align;
  final bool rtl;
  final Widget? preview;
  final ValueNotifier<Offset?> drag;
  final ValueChanged<_ContextMenuLayerState?> attach;
  final VoidCallback close;
  const _ContextMenuLayer({
    required this.animation,
    required this.frame,
    required this.fromScale,
    required this.onPreviewPressed,
    required this.screenPreview,
    required this.items,
    required this.title,
    required this.align,
    required this.rtl,
    required this.preview,
    required this.drag,
    required this.attach,
    required this.close,
  });
  @override
  State<_ContextMenuLayer> createState() => _ContextMenuLayerState();
}

class _ContextMenuLayerState extends State<_ContextMenuLayer>
    with SingleTickerProviderStateMixin {
  late final spring = AnimationController.unbounded(vsync: this);
  late List<AppMenuItem> items = widget.items;
  final history = <List<AppMenuItem>>[];
  List<_Entry> makeEntries(List<AppMenuItem> items) => [
    for (final item in items) ...[
      if (item.separatorBefore && item != items.first) const _Entry(null),
      _Entry(item),
    ],
  ];
  late List<_Entry> entries = makeEntries(items);
  late List<GlobalKey> rowKeys = [for (final _ in entries) GlobalKey()];
  void replaceItems(List<AppMenuItem> next) {
    setState(() {
      items = next;
      entries = makeEntries(items);
      rowKeys = [for (final _ in entries) GlobalKey()];
      highlighted = null;
    });
  }

  int? highlighted;
  bool chosen = false;

  @override
  void initState() {
    super.initState();
    widget.attach(this);
    widget.drag.addListener(dragged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        spring.value = 1;
      } else {
        spring.animateWith(SpringSimulation(_Menu.spring, 0, 1, 0));
      }
    });
  }

  @override
  void dispose() {
    widget.drag.removeListener(dragged);
    widget.attach(null);
    spring.dispose();
    super.dispose();
  }

  int? rowAt(Offset global) {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].separator) continue;
      final box = rowKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      if ((box.localToGlobal(Offset.zero) & box.size).contains(global)) {
        return i;
      }
    }
    return null;
  }

  void dragged() {
    final point = widget.drag.value;
    final next = point == null ? null : rowAt(point);
    if (next != highlighted) {
      if (next != null) HapticFeedback.selectionClick();
      setState(() => highlighted = next);
    }
  }

  /// The opening finger lifted: choose the action under it, if any.
  void release(Offset global) {
    final index = rowAt(global);
    if (index != null) choose(index);
  }

  void choose(int index) {
    if (chosen) return;
    final item = entries[index].item!;
    if (item.children != null && item.children!.isNotEmpty) {
      history.add(items);
      replaceItems([
        AppMenuItem(
          title: MaterialLocalizations.of(context).backButtonTooltip,
          symbol: 'chevron.backward',
          keepOpen: true,
          onPressed: () => replaceItems(history.removeLast()),
        ),
        ...item.children!,
      ]);
      return;
    }
    if (item.keepOpen) {
      item.onPressed?.call();
      return;
    }
    chosen = true;
    widget.close();
    Future.delayed(const Duration(milliseconds: 60), item.onPressed);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(1);
    final size = media.size;
    final insets = media.padding;
    final reduced = media.disableAnimations;
    final font = AppDesign.font(17);
    final rowHeight = math.max(
      44.0,
      (22 * scale).roundToDouble() + _Menu.verticalInset * 2,
    );
    final titleHeight = widget.title == null
        ? 0.0
        : (13 * scale).roundToDouble() + 22;
    final hasIcons = items.any(
      (i) => i.symbol != null || i.fallback != null || i.iconAsset != null,
    );
    // Text-measured width between Telegram's 220 and 240pt.
    var textWidth = 0.0;
    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(text: item.title, style: font.merge(item.textStyle)),
        textScaler: media.textScaler,
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      textWidth = math.max(textWidth, painter.width);
    }
    final menuHeight =
        _Menu.listInset * 2 +
        titleHeight +
        entries.fold(
          0.0,
          (sum, e) => sum + (e.separator ? _Menu.separatorHeight : rowHeight),
        );
    double clamp(double v, double lo, double hi) =>
        math.max(lo, math.min(math.max(lo, hi), v));
    final left = insets.left + _Menu.edgeInset, top = insets.top + 12;
    final right = math.max(left, size.width - insets.right - _Menu.edgeInset);
    final bottom = math.max(top, size.height - insets.bottom - 12);
    final width = math.min(
      right - left,
      clamp(
        (hasIcons ? _Menu.titleX : _Menu.sideInset) +
            textWidth +
            _Menu.sideInset,
        _Menu.minWidth,
        _Menu.maxWidth,
      ),
    );
    final height = math.max(
      1.0,
      math.min(
        menuHeight,
        bottom -
            top -
            (widget.screenPreview
                ? math.min(_Menu.previewMinHeight, (bottom - top) / 2) +
                      _Menu.previewSpacing
                : 0),
      ),
    );
    final anchor = widget.frame;
    // Content near the bottom (the send button) keeps its place and the
    // actions open above it when there is room (ChatSendMessageContextScreen).
    final placeAbove =
        anchor.bottom + _Menu.contentSpacing + height > bottom &&
        anchor.top - _Menu.contentSpacing - height >= top &&
        anchor.height <= bottom - top - height - _Menu.contentSpacing;
    // The content keeps its place unless the actions would not fit below it;
    // then it moves up just enough (ExtractedPresentationNode).
    final previewHeight = math.min(
      anchor.height,
      math.max(0.0, bottom - top - height - _Menu.contentSpacing),
    );
    // Short bubbles lift whole; tall ones are clipped to the room left.
    final showPreview =
        widget.preview != null &&
        (previewHeight >= anchor.height || previewHeight >= 44);
    final previewTop = placeAbove
        ? anchor.top
        : showPreview
        ? clamp(
            anchor.top,
            top,
            bottom - previewHeight - _Menu.contentSpacing - height,
          )
        : anchor.top;
    final previewLeft = anchor.left;
    final alignRight = switch (widget.align) {
      AppMenuAlign.right => true,
      AppMenuAlign.left => false,
      AppMenuAlign.center => false,
      AppMenuAlign.auto => anchor.center.dx > size.width / 2,
    };
    // actionsFrame.x: content minX + 6 - 4 (incoming) or maxX - 6 - w - 1.
    final preferredX = widget.align == AppMenuAlign.center
        ? anchor.center.dx - width / 2
        : alignRight
        ? anchor.right - 7 - width
        : anchor.left + 2;
    final below = showPreview
        ? previewTop + previewHeight + _Menu.contentSpacing
        : anchor.bottom + _Menu.contentSpacing;
    final above = placeAbove || (below + height > bottom && !showPreview);
    final menuTop = above
        ? clamp(
            anchor.top - _Menu.contentSpacing - height,
            top,
            bottom - height,
          )
        : clamp(below, top, bottom - height);
    var menuLeft = clamp(preferredX, left, right - width);
    var menuTop2 = menuTop, menuAbove = above, menuRight = alignRight;
    // `.controller` content: the previewed screen is centred on the display
    // with the actions under its trailing edge, wherever the row was.
    Rect? screen;
    if (widget.screenPreview && widget.preview != null) {
      final contentTop = insets.top + _Menu.previewTopInset;
      final floor = size.height - _Menu.previewBottomInset - insets.bottom;
      final h = math.max(
        _Menu.previewMinHeight,
        math.min(
          math.min(
            _Menu.previewMaxHeight,
            size.height - _Menu.edgeInset * 2 - contentTop - insets.bottom,
          ),
          floor - contentTop - _Menu.previewSpacing - height,
        ),
      );
      var y = math.max(contentTop, (size.height - h) / 2);
      final total = h + _Menu.previewSpacing + height;
      if (y + total > floor) y = math.max(contentTop, floor - total);
      screen = Rect.fromLTWH(
        (size.width -
                math.min(
                  size.width - _Menu.edgeInset * 2,
                  size.shortestSide >= 600 ? 400.0 : size.width,
                )) /
            2,
        y,
        math.min(
          size.width - _Menu.edgeInset * 2,
          size.shortestSide >= 600 ? 400.0 : size.width,
        ),
        h,
      );
      menuRight = !widget.rtl;
      menuAbove = false;
      menuTop2 = math.min(screen.bottom + _Menu.previewSpacing, floor - height);
      menuLeft = menuRight ? screen.right - width : screen.left;
    }
    final separator = dark ? const Color(0x1fffffff) : const Color(0x24000000);
    final hairline = 1 / media.devicePixelRatio;
    final hasChecks = items.any((item) => item.checked != null);
    final fade = widget.animation.drive(CurveTween(curve: Curves.easeInOut));
    double presentationProgress() => reduced
        ? 1
        : widget.animation.status == AnimationStatus.reverse
        ? Curves.easeInOut.transform(widget.animation.value)
        : spring.value;
    final motion = Listenable.merge([spring, widget.animation]);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: reduced ? kAlwaysCompleteAnimation : fade,
            child: GestureDetector(
              onTap: widget.close,
              // Blurred, dimmed chat behind the extracted message.
              child: AppBackdropBlur(
                intensity: 30,
                dark: dark,
                tint: dark ? const Color(0x66000000) : const Color(0x26000000),
              ),
            ),
          ),
        ),
        if (screen != null)
          Positioned.fromRect(
            rect: screen,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPreviewPressed,
              child: FadeTransition(
                opacity: reduced ? kAlwaysCompleteAnimation : fade,
                child: AnimatedBuilder(
                  animation: motion,
                  // The screen grows out of the pressed row into place.
                  builder: (context, child) {
                    final t = presentationProgress();
                    return Transform.translate(
                      offset: Offset(
                        0,
                        (anchor.center.dy - screen!.center.dy) * (1 - t),
                      ),
                      child: Transform.scale(
                        key: const ValueKey('context.preview.transform'),
                        scale: math.max(.01, .01 + .99 * t),
                        child: child,
                      ),
                    );
                  },
                  child: IgnorePointer(child: widget.preview),
                ),
              ),
            ),
          )
        else if (showPreview)
          Positioned(
            left: previewLeft,
            top: previewTop,
            width: anchor.width,
            height: previewHeight,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: spring,
                builder: (context, child) => Transform.scale(
                  scale:
                      widget.fromScale + (1 - widget.fromScale) * spring.value,
                  child: child,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: anchor.height,
                    maxHeight: anchor.height,
                    child: widget.preview,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: menuLeft,
          top: menuTop2,
          width: width,
          height: height,
          child: FadeTransition(
            opacity: reduced ? kAlwaysCompleteAnimation : fade,
            child: AnimatedBuilder(
              animation: motion,
              builder: (context, child) => Opacity(
                // animateAlpha(0 -> 1, 0.05s) alongside the spring.
                opacity: (presentationProgress() * 8).clamp(0.0, 1.0),
                child: Transform.scale(
                  key: const ValueKey('context.actions.transform'),
                  alignment: Alignment(menuRight ? 1 : -1, menuAbove ? 1 : -1),
                  scale: math.max(.01, presentationProgress()),
                  child: child,
                ),
              ),
              child: GlassSurface(
                key: const ValueKey('context.actions.surface'),
                role: GlassSurfaceRole.menu,
                useOwnLayer: true,
                radius: math.min(30, height / 2),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: _Menu.listInset,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.title != null)
                        Container(
                          constraints: BoxConstraints(minHeight: titleHeight),
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 11),
                          child: Text(
                            widget.title!,
                            textAlign: TextAlign.center,
                            style: AppDesign.font(
                              13,
                              color: palette.secondaryLabel,
                            ),
                          ),
                        ),
                      for (var i = 0; i < entries.length; i++)
                        entries[i].separator
                            ? SizedBox(
                                key: rowKeys[i],
                                height: _Menu.separatorHeight,
                                child: Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: _Menu.sideInset,
                                    ),
                                    height: hairline,
                                    color: separator,
                                  ),
                                ),
                              )
                            : _MenuRow(
                                key: rowKeys[i],
                                item: entries[i].item!,
                                height: rowHeight,
                                icons: hasIcons,
                                checks: hasChecks,
                                highlighted: highlighted == i,
                                onHighlight: (value) => setState(
                                  () => highlighted = value
                                      ? i
                                      : highlighted == i
                                      ? null
                                      : highlighted,
                                ),
                                onTap: () => choose(i),
                              ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ContextControllerActionsStackNode item: icon in a 32pt slot 20pt from the
/// leading edge, 17pt title at 60pt, 11pt vertical insets, and a 10pt-inset
/// pill highlight (radius min(20, h/2), 10% black or white).
class _MenuRow extends StatelessWidget {
  final AppMenuItem item;
  final double height;
  final bool icons, checks, highlighted;
  final ValueChanged<bool> onHighlight;
  final VoidCallback onTap;
  const _MenuRow({
    super.key,
    required this.item,
    required this.height,
    required this.icons,
    required this.checks,
    required this.highlighted,
    required this.onHighlight,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = item.destructive ? palette.destructive : palette.text;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      checked: item.checked,
      label: item.title,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onHighlight(true),
        onTapCancel: () => onHighlight(false),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                left: 10,
                right: 10,
                child: AnimatedOpacity(
                  opacity: highlighted ? 1 : 0,
                  duration: highlighted || reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0x1affffff)
                          : const Color(0x1a000000),
                      borderRadius: BorderRadius.circular(
                        math.min(20, height / 2),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    if (icons)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: _Menu.iconSideInset,
                          end:
                              _Menu.titleX -
                              _Menu.iconSideInset -
                              _Menu.iconSlot,
                        ),
                        child: SizedBox(
                          width: _Menu.iconSlot,
                          child: Center(
                            child: item.iconAsset != null
                                ? SvgPicture.asset(
                                    item.iconAsset!,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.contain,
                                  )
                                : item.symbol != null
                                ? AppSymbol.icon(
                                    item.symbol!,
                                    size: 24,
                                    color: color,
                                    fallback: item.fallback,
                                  )
                                : item.fallback == null
                                ? null
                                : Icon(item.fallback, size: 24, color: color),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: _Menu.sideInset),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesign.font(
                          17,
                          color: color,
                        ).merge(item.textStyle),
                      ),
                    ),
                    if (item.children?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: palette.secondaryLabel,
                        ),
                      ),
                    if (checks)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: SizedBox(
                          width: 18,
                          child: item.checked == true
                              ? AppSymbol.icon(
                                  'checkmark',
                                  size: 15,
                                  color: palette.text,
                                  fallback: Icons.check,
                                )
                              : null,
                        ),
                      ),
                    const SizedBox(width: _Menu.sideInset),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
