import '../l10n/l10n.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// The one "Hide with spoiler" renderer (Telegram MediaDustNode): the content
/// is blurred under drifting dust until tapped, then revealed by a circle
/// growing from the touch. Reduce Motion keeps the dust still and reveals at
/// once.
class SpoilerOverlay extends StatefulWidget {
  final bool hidden;
  final Widget child;
  const SpoilerOverlay({super.key, required this.hidden, required this.child});
  @override
  State<SpoilerOverlay> createState() => _SpoilerOverlayState();
}

class _SpoilerOverlayState extends State<SpoilerOverlay>
    with TickerProviderStateMixin {
  late bool hidden = widget.hidden;
  late final reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Ticker ticker = createTicker((elapsed) {
    time.value = elapsed.inMicroseconds / 1e6;
  });
  final time = ValueNotifier<double>(0);
  Offset origin = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (hidden && !still && !ticker.isActive) ticker.start();
    if (still && ticker.isActive) ticker.stop();
  }

  @override
  void didUpdateWidget(SpoilerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hidden && !oldWidget.hidden) {
      hidden = true;
      reveal.value = 0;
      if (!MediaQuery.disableAnimationsOf(context)) ticker.start();
    }
  }

  @override
  void dispose() {
    ticker.dispose();
    reveal.dispose();
    time.dispose();
    super.dispose();
  }

  Future<void> show(Offset at) async {
    HapticFeedback.lightImpact();
    origin = at;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await reveal.forward(from: 0);
    }
    if (!mounted) return;
    ticker.stop();
    setState(() => hidden = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!hidden) return widget.child;
    return Semantics(
      button: true,
      label: context.l10n.spoilerTapToReveal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => show(details.localPosition),
        child: Builder(
          builder: (context) {
            return Stack(
              fit: StackFit.passthrough,
              children: [
                IgnorePointer(child: widget.child),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: reveal,
                    builder: (context, child) => reveal.value == 0
                        ? child!
                        : ClipPath(
                            clipper: _HoleClipper(
                              origin,
                              Curves.easeIn.transform(reveal.value),
                            ),
                            child: child,
                          ),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: ColoredBox(
                          color: const Color(0x33000000),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _DustPainter(time),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Everything except a circle around [origin] growing to the far corner.
class _HoleClipper extends CustomClipper<Path> {
  final Offset origin;
  final double progress;
  _HoleClipper(this.origin, this.progress);
  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()..addOval(
      Rect.fromCircle(
        center: origin,
        radius: progress * (size.width + size.height),
      ),
    ),
  );
  @override
  bool shouldReclip(_HoleClipper old) =>
      old.origin != origin || old.progress != progress;
}

/// Deterministic drifting particles, about one per 40pt² like the dust.
class _DustPainter extends CustomPainter {
  final ValueNotifier<double> time;
  _DustPainter(this.time) : super(repaint: time);
  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width * size.height / 40).clamp(60, 1600).toInt();
    final random = math.Random(7);
    final paint = Paint();
    final t = time.value;
    for (var i = 0; i < count; i++) {
      final speed = 6 + random.nextDouble() * 14;
      final angle = random.nextDouble() * math.pi * 2;
      final phase = random.nextDouble() * 4;
      final life = ((t + phase) % 4) / 4;
      final x =
          (random.nextDouble() * size.width + math.cos(angle) * speed * t) %
          size.width;
      final y =
          (random.nextDouble() * size.height + math.sin(angle) * speed * t) %
          size.height;
      final alpha = math.sin(life * math.pi) * .9;
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(x < 0 ? x + size.width : x, y < 0 ? y + size.height : y),
        .7 + random.nextDouble() * .6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => false;
}
