import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/appearance.dart';
import '../core/session.dart';
import '../core/wallpaper_mesh.dart';
import '../design/app_design.dart';

/// Source components/chat/ChatWallpaper.tsx (tweb background layers): the
/// mesh gradient (rotation as phase), an optional photo, and the pattern
/// soft-light blended at its intensity or, on Night, cut out of black.
class ChatWallpaper extends StatefulWidget {
  final bool? dark;

  /// Preview a resolved appearance instead of the current theme's.
  final ResolvedAppearance? appearance;
  final bool thumbnail;
  const ChatWallpaper({
    super.key,
    this.dark,
    this.appearance,
    this.thumbnail = false,
  });
  @override
  State<ChatWallpaper> createState() => _ChatWallpaperState();
}

const _patterns = {
  '/images/chat/theme-OdiX5W17EmeBL4Us.svg':
      'assets/chat/theme-OdiX5W17EmeBL4Us.png',
  '/images/chat/theme-FUtC4daANprHzpNE.svg':
      'assets/chat/theme-FUtC4daANprHzpNE.png',
  '/images/chat/theme-HWyC5JgYOmydc1CH.svg':
      'assets/chat/theme-HWyC5JgYOmydc1CH.png',
  '/images/chat/theme-ZtE0ghOnKM11pfzD.svg':
      'assets/chat/theme-ZtE0ghOnKM11pfzD.png',
  '/images/chat/theme-glhuaQsVnm5Ui6H0.svg':
      'assets/chat/theme-glhuaQsVnm5Ui6H0.png',
  '/images/chat/theme-fzyYZ89JqdFc8P1o.svg':
      'assets/chat/theme-fzyYZ89JqdFc8P1o.png',
  '/images/chat/theme-mwUbCd6C1Jx6SGmb.svg':
      'assets/chat/theme-mwUbCd6C1Jx6SGmb.png',
  '/images/chat/theme-nmt7Q0OtB9ZaoTYM.svg':
      'assets/chat/theme-nmt7Q0OtB9ZaoTYM.png',
};

class _ChatWallpaperState extends State<ChatWallpaper> {
  ui.Image? pattern;
  String? patternAsset;

  void loadPattern(String asset) {
    if (asset == patternAsset) return;
    patternAsset = asset;
    final stream = AssetImage(
      asset,
    ).resolve(createLocalImageConfiguration(context));
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (mounted && patternAsset == asset)
        setState(() => pattern = info.image);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final session = context
        .dependOnInheritedWidgetOfExactType<AppScope>()
        ?.notifier;
    final resolved =
        widget.appearance ??
        palette.resolved ??
        resolveTheme(
          (widget.dark ?? Theme.of(context).brightness == Brightness.dark)
              ? BaseTheme.night
              : BaseTheme.day,
        );
    final wp = resolved.wallpaper;
    loadPattern(_patterns[wp.source] ?? 'assets/chat/telegram-pattern.png');
    final image = widget.appearance == null ? session?.wallpaperImage : null;
    final photo = wp.kind == 'image' && image != null;
    final nightMask =
        !widget.thumbnail &&
        resolved.base == BaseTheme.night &&
        wp.pattern &&
        !photo;
    final colors = wp.colors
        .map((c) => int.parse(c.substring(1), radix: 16))
        .toList();
    final phase = (wp.rotation / 45).round() % 8;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<ui.Image>(
            future: wallpaperMesh(colors, phase: phase),
            builder: (context, snapshot) => CustomPaint(
              painter: _WallpaperPainter(
                mesh: snapshot.data,
                pattern: photo || !wp.pattern ? null : pattern,
                base: Color(0xff000000 | colors.first),
                nightMask: nightMask,
                white: resolved.base == BaseTheme.tinted,
                intensity: wp.intensity / 100,
                windowHeight: MediaQuery.sizeOf(context).height,
              ),
              size: Size.infinite,
            ),
          ),
          if (photo)
            Positioned.fill(
              child: wp.blur
                  ? ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: 10,
                        sigmaY: 10,
                        tileMode: TileMode.mirror,
                      ),
                      child: Image.file(File(image), fit: BoxFit.cover),
                    )
                  : Image.file(File(image), fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  final ui.Image? mesh, pattern;
  final Color base;
  final bool nightMask, white;
  final double intensity, windowHeight;
  _WallpaperPainter({
    required this.mesh,
    required this.pattern,
    required this.base,
    required this.nightMask,
    required this.white,
    required this.intensity,
    required this.windowHeight,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawColor(nightMask ? Colors.black : base, BlendMode.src);
    if (mesh == null) return;
    // The mesh overscans 25% above and below (meshFrame).
    final meshBounds = Rect.fromLTWH(
      0,
      -size.height * .25,
      size.width,
      size.height * 1.5,
    );
    const source = Rect.fromLTWH(0, 0, 50, 50);
    final quality = Paint()..filterQuality = FilterQuality.medium;
    if (!nightMask) canvas.drawImageRect(mesh!, source, meshBounds, quality);
    if (pattern == null) return;
    // CSS background-size auto calc(500px + 40vh), centred vertically.
    final height = 500 + windowHeight * .4, width = height * 1440 / 2960;
    final centered = (size.height - height) / 2;
    final firstY = centered > 0
        ? centered - (centered / height).ceil() * height
        : centered;
    final patternSource = Rect.fromLTWH(
      0,
      0,
      pattern!.width.toDouble(),
      pattern!.height.toDouble(),
    );
    void tiles(Paint paint) {
      for (double x = 0; x < size.width; x += width) {
        for (double y = firstY; y < size.height; y += height) {
          canvas.drawImageRect(
            pattern!,
            patternSource,
            Rect.fromLTWH(x, y, width, height),
            paint,
          );
        }
      }
    }

    if (nightMask) {
      // The pattern is the alpha mask through which the mesh shows on black.
      canvas.saveLayer(bounds, Paint());
      tiles(Paint()..filterQuality = FilterQuality.medium);
      canvas.drawImageRect(
        mesh!,
        source,
        meshBounds,
        Paint()
          ..blendMode = BlendMode.srcIn
          ..color = Colors.white.withValues(alpha: (intensity / 2).clamp(.3, 1))
          ..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      return;
    }
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.softLight);
    tiles(
      Paint()
        ..color = Colors.white.withValues(alpha: intensity.clamp(0, 1))
        ..colorFilter = white
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null
        ..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      mesh != old.mesh ||
      pattern != old.pattern ||
      base != old.base ||
      nightMask != old.nightMask ||
      white != old.white ||
      intensity != old.intensity ||
      windowHeight != old.windowHeight;
}
