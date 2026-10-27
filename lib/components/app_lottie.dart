import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// One cached Lottie renderer. App lifecycle, tab visibility and Reduce Motion
/// decide playback; reduced motion displays [staticProgress].
class AppLottie extends StatefulWidget {
  final String asset;
  final double size;
  final bool autoplay, loop;
  final Color? color;
  final double staticProgress;

  /// Called once when the document cannot be loaded or decoded.
  final VoidCallback? onError;
  const AppLottie({
    this.onError,
    super.key,
    required this.asset,
    this.size = 120,
    this.autoplay = true,
    this.loop = true,
    this.color,
    this.staticProgress = 0,
  });
  @override
  State<AppLottie> createState() => _AppLottieState();
}

class _AppLottieState extends State<AppLottie>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final controller = AnimationController(vsync: this);
  bool foreground = true;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void playback() {
    if (!ready || !mounted) return;
    final animate =
        foreground &&
        widget.autoplay &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate) {
      if (widget.loop) {
        if (!controller.isAnimating) controller.repeat();
      } else {
        controller.forward();
      }
    } else {
      controller.stop();
      if (!widget.autoplay || MediaQuery.disableAnimationsOf(context)) {
        controller.value = widget.staticProgress.clamp(0.0, 1.0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    playback();
  }

  @override
  void didUpdateWidget(AppLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      ready = false;
      controller.stop();
      controller.value = 0;
    }
    if (!oldWidget.autoplay && widget.autoplay && !widget.loop) {
      controller.value = 0;
    }
    playback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    playback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: widget.color == null
          ? _animation()
          : ColorFiltered(
              colorFilter: ColorFilter.mode(widget.color!, BlendMode.srcIn),
              child: _animation(),
            ),
    ),
  );
  Widget _animation() {
    void loaded(LottieComposition composition) {
      if (!mounted) return;
      controller.duration = composition.duration;
      ready = true;
      playback();
    }

    Widget failed(BuildContext context, Object error, StackTrace? stack) {
      if (widget.onError != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onError!();
        });
        return const SizedBox.shrink();
      }
      return const Icon(Icons.image_not_supported_outlined);
    }

    return widget.asset.startsWith('https://') ||
            widget.asset.startsWith('http://')
        ? Lottie.network(
            widget.asset,
            controller: controller,
            repeat: widget.loop,
            decoder: widget.asset.split('?').first.endsWith('.tgs')
                ? LottieComposition.decodeGZip
                : null,
            onLoaded: loaded,
            errorBuilder: failed,
          )
        : Lottie.asset(
            widget.asset,
            controller: controller,
            repeat: widget.loop,
            onLoaded: loaded,
            errorBuilder: failed,
          );
  }
}
