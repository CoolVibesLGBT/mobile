import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';

/// Press feedback of the source React Native components. Pressable style
/// functions apply on touch down and clear on up/cancel without animation.
/// - [opacity]: bar/toolbar glyphs and text links, alpha .5.
/// - [button]: components/ui/Button.tsx, alpha .86 and scale .98.
/// - [row]: NativeRow, itemHighlightedBackgroundColor fill, 400ms fade out.
/// - [glass]: Telegram's size-based lift, directional stretch and release spring.
/// - [radar]: Match/index.tsx bubble, scale .9 and alpha .8.
/// - [touchable]: NativeTouchable TouchableOpacity, alpha .55.
/// - [iconButton]: Button.tsx IconButton, alpha .86 and scale .96.
/// - [native]: no Flutter feedback (UIKit control draws its own highlight).
enum AppPressStyle {
  opacity,
  button,
  row,
  glass,
  radar,
  tag,
  native,
  emoji,
  touchable,
  iconButton,
}

class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed, onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;
  final String label;
  final bool selected, haptic;

  /// Observes pressure without claiming taps, selection, focus or semantics.
  /// Editors retain complete ownership of their gestures and accessibility.
  final bool observeOnly, enabled;
  final AppPressStyle style;
  final double disabledOpacity;
  final double? pressedScale;
  final ValueChanged<bool>? onHighlightChanged;
  const AppPressable({
    super.key,
    required this.child,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.onLongPressCancel,
    this.selected = false,
    this.haptic = false,
    this.observeOnly = false,
    this.enabled = true,
    this.style = AppPressStyle.opacity,
    this.disabledOpacity = 1,
    this.pressedScale,
    this.onHighlightChanged,
  });
  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable>
    with SingleTickerProviderStateMixin {
  bool pressed = false;
  bool get enabled =>
      widget.enabled &&
      (widget.observeOnly ||
          widget.onPressed != null ||
          widget.onLongPress != null ||
          widget.onLongPressStart != null);
  AnimationController? _glassAnimation;
  Matrix4 _glassFrom = Matrix4.identity(), _glassTo = Matrix4.identity();
  Size _glassSize = Size.zero;
  int? _pointer;
  Offset? _origin;
  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
  AnimationController get _glassController =>
      _glassAnimation ??= AnimationController.unbounded(vsync: this, value: 1);
  Matrix4 get _glassTransform => Matrix4Tween(
    begin: _glassFrom,
    end: _glassTo,
  ).transform(_glassAnimation?.value ?? 1);

  Matrix4 _pressureTransform(Offset drag) {
    final width = math.max(1.0, _glassSize.width);
    final height = math.max(1.0, _glassSize.height);
    final aspect = width / height;
    final scale = 1 + AppDesign.glassPressGrowth / math.max(width, height);
    final vector = Offset(drag.dx / aspect, drag.dy);
    final length = vector.distance;
    var sx = scale, sy = scale;
    var offset = Offset.zero;
    if (length > 0) {
      final normal = vector / length;
      final k =
          1 -
          1 /
              ((length / height) / (AppDesign.glassDragResistance * aspect) +
                  1);
      final stretch = AppDesign.glassStretchExtent / height * k;
      final difference = normal.dx.abs() - normal.dy.abs();
      final factor = 1 + stretch * difference.abs();
      sx *= difference > 0 ? factor : 1 / factor;
      sy *= difference > 0 ? 1 / factor : factor;
      offset = normal * (AppDesign.glassDragOffset * k);
    }
    return Matrix4.identity()
      ..setEntry(0, 0, sx)
      ..setEntry(1, 1, sy)
      ..setEntry(0, 3, offset.dx)
      ..setEntry(1, 3, offset.dy);
  }

  void _animateGlass(bool down) {
    if (widget.style != AppPressStyle.glass) return;
    if (_reduceMotion || !enabled) {
      _resetGlass();
      return;
    }
    _glassFrom = _glassTransform;
    _glassTo = down ? _pressureTransform(Offset.zero) : Matrix4.identity();
    _glassController.animateWith(
      SpringSimulation(
        down ? AppDesign.glassLiftOn : AppDesign.glassLiftOff,
        0,
        1,
        0,
      ),
    );
  }

  void _resetGlass() {
    _pointer = null;
    _origin = null;
    _glassFrom = _glassTo = Matrix4.identity();
    _glassAnimation?.stop();
    _glassAnimation?.value = 1;
  }

  void _down(PointerDownEvent event) {
    if (!enabled || _pointer != null) return;
    _pointer = event.pointer;
    _origin = event.position;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) _glassSize = box.size;
    highlight(true);
  }

  void _move(PointerMoveEvent event) {
    if (widget.style != AppPressStyle.glass ||
        !enabled ||
        _reduceMotion ||
        _pointer != event.pointer ||
        _origin == null ||
        !pressed) {
      return;
    }
    // Like TouchEffect.setStretchVector(animated: false), follow the finger
    // immediately; only lift/release use springs. Global coordinates prevent
    // the transform itself from feeding back into the drag distance.
    final transform = _pressureTransform(event.position - _origin!);
    _glassFrom = _glassTo = transform;
    _glassController.stop();
    _glassController.value = 1;
  }

  void _up(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _origin = null;
    highlight(false);
  }

  void highlight(bool value) {
    if (pressed != value) {
      _animateGlass(value);
      setState(() => pressed = value);
      widget.onHighlightChanged?.call(value);
    }
  }

  @override
  void didUpdateWidget(AppPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!enabled && pressed) {
      pressed = false;
      _resetGlass();
      widget.onHighlightChanged?.call(false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion || !TickerMode.valuesOf(context).enabled) {
      _resetGlass();
      pressed = false;
    }
  }

  @override
  void dispose() {
    _glassAnimation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final child = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppDesign.minimumTarget,
        minHeight: AppDesign.minimumTarget,
      ),
      child: widget.child,
    );
    final Widget content = switch (widget.style) {
      AppPressStyle.native => child,
      AppPressStyle.glass => AnimatedBuilder(
        animation: _glassController,
        child: child,
        builder: (context, child) => Transform(
          alignment: Alignment.center,
          transform: _reduceMotion ? Matrix4.identity() : _glassTransform,
          child: child,
        ),
      ),
      AppPressStyle.emoji => AnimatedScale(
        scale: pressed && !reduced ? widget.pressedScale ?? .7 : 1,
        duration: reduced
            ? Duration.zero
            : Duration(milliseconds: pressed ? 120 : 380),
        curve: pressed ? Curves.easeOut : Curves.elasticOut,
        child: child,
      ),
      AppPressStyle.tag => Transform.scale(
        scale: pressed ? .92 : 1,
        child: Opacity(opacity: pressed ? .85 : 1, child: child),
      ),
      AppPressStyle.radar => Transform.scale(
        scale: pressed ? .9 : 1,
        child: Opacity(opacity: pressed ? .8 : 1, child: child),
      ),
      AppPressStyle.button => Transform.scale(
        scale: pressed ? .98 : 1,
        child: Opacity(
          opacity: !enabled
              ? widget.disabledOpacity
              : pressed
              ? .86
              : 1,
          child: child,
        ),
      ),
      AppPressStyle.row => AnimatedContainer(
        duration: pressed || reduced ? Duration.zero : AppDesign.rowRelease,
        color: pressed || widget.selected
            ? AppPalette.of(context).highlight
            : AppPalette.of(context).highlight.withValues(alpha: 0),
        child: child,
      ),
      AppPressStyle.touchable => AnimatedOpacity(
        opacity: pressed ? .55 : 1,
        duration: reduced
            ? Duration.zero
            : Duration(milliseconds: pressed ? 150 : 250),
        child: child,
      ),
      AppPressStyle.iconButton => Transform.scale(
        scale: pressed ? .96 : 1,
        child: Opacity(opacity: pressed ? .86 : 1, child: child),
      ),
      AppPressStyle.opacity => Opacity(
        opacity: !enabled
            ? (widget.disabledOpacity == 1 ? .35 : widget.disabledOpacity)
            : pressed
            ? .5
            : 1,
        child: child,
      ),
    };
    if (widget.observeOnly) {
      return Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: content,
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label.isEmpty ? null : widget.label,
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => highlight(true) : null,
          onTapCancel: () => highlight(false),
          onTapUp: (_) => highlight(false),
          onTap: widget.onPressed == null
              ? null
              : () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onPressed!();
                },
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  highlight(false);
                  widget.onLongPress!();
                },
          onLongPressStart: widget.onLongPressStart,
          onLongPressMoveUpdate: widget.onLongPressMoveUpdate,
          onLongPressEnd: widget.onLongPressEnd,
          onLongPressCancel: widget.onLongPressCancel,
          child: content,
        ),
      ),
    );
  }
}
