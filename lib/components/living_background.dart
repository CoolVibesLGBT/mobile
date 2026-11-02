import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// One shared drift signal for a whole radar screen — the device's tilt
/// (accelerometer gravity vector, low-pass filtered) with a slow automatic
/// loop as a fallback when no sample has arrived for a bit (simulator,
/// desktop, a sensor-less device). Every background and bubble on the
/// screen reads the same instance via [DriftingImage] so they move as one
/// coherent layer instead of each spinning up its own sensor subscription.
class RadarMotion extends ChangeNotifier {
  double x = 0, y = 0;
  bool sensorActive = false;
  late final AnimationController _auto;
  StreamSubscription<AccelerometerEvent>? _sensor;
  Timer? _timeout;

  RadarMotion(TickerProvider vsync) {
    _auto = AnimationController(vsync: vsync, duration: const Duration(seconds: 24))
      ..addListener(notifyListeners)
      ..repeat();
    // sensors_plus only ships android/ios/web implementations (see its
    // pubspec); every method on its channel — including the sampling-period
    // setup accelerometerEventStream() does internally, outside the stream's
    // own onError — throws MissingPluginException elsewhere (macOS, Linux,
    // Windows desktop). The auto-loop above is the deliberate fallback for
    // exactly that case, so skip the subscription there instead of reaching
    // for a channel that was never registered.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      _sensor = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(_onReading, onError: (_) {}, cancelOnError: true);
    }
  }

  void _onReading(AccelerometerEvent event) {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 2), () {
      sensorActive = false;
      notifyListeners();
    });
    sensorActive = true;
    x = x * .85 + (event.x / 9.8).clamp(-1.0, 1.0) * .15;
    y = y * .85 + (event.y / 9.8).clamp(-1.0, 1.0) * .15;
    notifyListeners();
  }

  /// The auto-loop's phase (0..2π, continuously looping) — for a shimmer or
  /// rotation that wants to stay "alive" without its own ticker.
  double get angle => _auto.value * 2 * math.pi;

  /// A drift offset within roughly +/-[ampX]/+/-[ampY], sensor-led when a
  /// recent reading exists, otherwise the automatic fallback loop.
  Offset offset(double ampX, double ampY) {
    if (sensorActive) {
      // Tilting the top of the phone away pulls the image toward the
      // viewer, matching the classic parallax-wallpaper feel.
      return Offset(-x * ampX, y * ampY);
    }
    final t = _auto.value * 2 * math.pi;
    return Offset(math.sin(t) * ampX * .5, math.cos(t * .6) * ampY * .5);
  }

  @override
  void dispose() {
    _sensor?.cancel();
    _timeout?.cancel();
    _auto.dispose();
    super.dispose();
  }
}

/// Applies [motion]'s drift to [child] — scaled up so panning never reveals
/// an edge, at [amplitude] (1 = the full background sweep; bubbles want a
/// much smaller fraction) — plus, when given, an [extra] live offset (e.g.
/// a drag gesture elsewhere on screen) added to the same drift, inside the
/// same clip. An offset applied *outside* this widget would move the whole
/// already-clipped image and bare a gap at whichever edge it slid away
/// from; added in here, it's clamped to the overscan [scale] actually
/// provides, so it can never exceed it. Off entirely under Reduce Motion.
class DriftingImage extends StatelessWidget {
  final RadarMotion motion;
  final Widget child;
  final double scale, amplitude;
  final Listenable? extra;
  final Offset Function()? extraOffset;
  const DriftingImage({
    super.key,
    required this.motion,
    required this.child,
    this.scale = 1.16,
    this.amplitude = 1,
    this.extra,
    this.extraOffset,
  });
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return LayoutBuilder(
      builder: (context, box) => ClipRect(
        child: AnimatedBuilder(
          animation: extra == null
              ? motion
              : Listenable.merge([motion, extra]),
          builder: (context, _) {
            final maxDx = box.maxWidth * (scale - 1) / 2;
            final maxDy = box.maxHeight * (scale - 1) / 2;
            final d =
                motion.offset(
                  box.maxWidth * .07 * amplitude,
                  box.maxHeight * .07 * amplitude,
                ) +
                (extraOffset?.call() ?? Offset.zero);
            return Transform.scale(
              scale: scale,
              child: Transform.translate(
                offset: Offset(
                  d.dx.clamp(-maxDx, maxDx),
                  d.dy.clamp(-maxDy, maxDy),
                ),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A crossfade that can't flash the widget behind it. AnimatedSwitcher's
/// default fades the outgoing child out at the same time as it fades the
/// incoming one in, so at the midpoint both are ~50% opaque and whatever
/// sits behind — here, a plain Scaffold background — shows through as a
/// white flash. The outgoing child stays fully opaque underneath instead;
/// only the incoming one animates in on top of it.
class FlashFreeCrossFade extends StatefulWidget {
  /// Must carry a Key identifying its content — a change in that key is
  /// what triggers the crossfade.
  final Widget child;
  final Duration duration;
  const FlashFreeCrossFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
  });
  @override
  State<FlashFreeCrossFade> createState() => _FlashFreeCrossFadeState();
}

class _FlashFreeCrossFadeState extends State<FlashFreeCrossFade>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => outgoing = null);
    }
  });
  Widget? outgoing;
  late Widget incoming = widget.child;

  @override
  void didUpdateWidget(FlashFreeCrossFade old) {
    super.didUpdateWidget(old);
    if (widget.child.key != incoming.key) {
      outgoing = incoming;
      incoming = widget.child;
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.value = 1;
      } else {
        controller
          ..value = 0
          ..forward();
      }
    } else {
      incoming = widget.child;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ?outgoing,
      AnimatedBuilder(
        animation: controller,
        builder: (context, child) =>
            Opacity(opacity: controller.value, child: child),
        child: incoming,
      ),
    ],
  );
}
