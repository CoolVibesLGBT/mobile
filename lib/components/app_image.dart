import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../design/app_design.dart';
import 'app_button.dart';

/// NativeImage fallback: an honest system placeholder on surface3Solid.
class _ImageFallback extends StatelessWidget {
  final double? width, height;
  final bool profile;
  const _ImageFallback({this.width, this.height, this.profile = false});
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff393939)
        : const Color(0xfff2f2f2),
    child: AppSymbol(
      profile ? 'person.crop.circle' : 'photo',
      size: 17,
      box: 24,
      color: AppPalette.of(context).secondaryLabel,
      fallback: profile ? Icons.account_circle_outlined : Icons.image_outlined,
    ),
  );
}

/// expo-image `transition`: a 150ms cross-fade once the network image decodes.
Widget _fadeIn(
  BuildContext context,
  Widget child,
  int? frame,
  bool synchronous,
) => synchronous
    ? child
    : AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: child,
      );

class AppImage extends StatelessWidget {
  final dynamic source;
  final double? width, height;
  final BoxFit fit;
  final String variant;
  final Map<String, String>? headers;
  final bool profile;
  const AppImage({
    this.profile = false,
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.variant = 'original',
    this.headers,
  });
  @override
  Widget build(BuildContext context) {
    if (source is AssetImage &&
        (source as AssetImage).assetName.endsWith('.svg')) {
      return SvgPicture.asset(
        (source as AssetImage).assetName,
        width: width,
        height: height,
        fit: fit,
      );
    }
    if (source is ImageProvider) {
      return Image(
        image: source as ImageProvider,
        errorBuilder: (_, _, _) =>
            _ImageFallback(width: width, height: height, profile: profile),
        width: width,
        height: height,
        fit: fit,
      );
    }
    final url = assetUrl(source, variant: variant);
    final headers =
        this.headers ??
        context
            .dependOnInheritedWidgetOfExactType<AppScope>()
            ?.notifier
            ?.api
            .mediaHeaders(url);
    if (url.isEmpty) {
      return _ImageFallback(width: width, height: height, profile: profile);
    }
    if (Uri.tryParse(url)?.path.endsWith('.svg') == true ||
        url.contains('/svg?')) {
      return SvgPicture.network(
        url,
        width: width,
        height: height,
        fit: fit,
        headers: headers,
        placeholderBuilder: (_) => const SizedBox.shrink(),
        errorBuilder: (_, _, _) =>
            _ImageFallback(width: width, height: height, profile: profile),
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      headers: headers,
      frameBuilder: (context, child, frame, synchronous) =>
          _fadeIn(context, child, frame, synchronous),
      errorBuilder: (_, _, _) =>
          _ImageFallback(width: width, height: height, profile: profile),
    );
  }
}
