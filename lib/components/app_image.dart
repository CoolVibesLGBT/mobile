import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

/// flutter_svg's SvgPicture.network lets a socket/DNS failure escape as an
/// unhandled Zone exception instead of reaching its own errorBuilder (seen
/// crashing the app when the dicebear fallback avatar is unreachable), so
/// the fetch is done by hand here where a thrown error is just a Future
/// rejection FutureBuilder can catch.
class _NetworkSvg extends StatefulWidget {
  final String url;
  final double? width, height;
  final BoxFit fit;
  final Map<String, String>? headers;
  final bool profile;
  const _NetworkSvg({
    required this.url,
    this.width,
    this.height,
    required this.fit,
    this.headers,
    required this.profile,
  });
  @override
  State<_NetworkSvg> createState() => _NetworkSvgState();
}

class _NetworkSvgState extends State<_NetworkSvg> {
  late Future<Uint8List> bytes = fetch();

  Future<Uint8List> fetch() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(widget.url));
      widget.headers?.forEach(request.headers.set);
      final response = await request.close();
      if (response.statusCode >= 400) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.tryParse(widget.url),
        );
      }
      final builder = BytesBuilder();
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return _stripMetadata(builder.takeBytes());
    } finally {
      client.close(force: true);
    }
  }

  /// The dicebear fallback avatar's generated SVGs carry a `<metadata>`
  /// element (generator/attribution info) that flutter_svg's parser doesn't
  /// support; per the SVG spec it's never rendered, so dropping it is
  /// lossless and stops flutter_svg logging "unhandled element
  /// `<metadata/>`" on every parse.
  static Uint8List _stripMetadata(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    if (!text.contains('<metadata')) return bytes;
    final stripped = text.replaceAll(
      RegExp(r'<metadata\b[^>]*?(/>|>.*?</metadata>)', dotAll: true),
      '',
    );
    return Uint8List.fromList(utf8.encode(stripped));
  }

  @override
  void didUpdateWidget(_NetworkSvg old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) bytes = fetch();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: bytes,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return _ImageFallback(
          width: widget.width,
          height: widget.height,
          profile: widget.profile,
        );
      }
      if (snapshot.hasError || snapshot.data == null) {
        return _ImageFallback(
          width: widget.width,
          height: widget.height,
          profile: widget.profile,
        );
      }
      return SvgPicture.memory(
        snapshot.data!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    },
  );
}

/// expo-image `transition`: a 150ms cross-fade once the network image
/// decodes. Before that frame lands, [placeholder] shows through instead of
/// nothing — an undecoded Image paints transparent, which otherwise reveals
/// whatever sits behind it (a glass bubble's tint reads as a white flash).
Widget _fadeIn(
  BuildContext context,
  Widget child,
  int? frame,
  bool synchronous,
  Widget placeholder,
) => synchronous
    ? child
    : Stack(
        fit: StackFit.passthrough,
        children: [
          if (frame == null) placeholder,
          AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: child,
          ),
        ],
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
      return _NetworkSvg(
        url: url,
        width: width,
        height: height,
        fit: fit,
        headers: headers,
        profile: profile,
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      headers: headers,
      frameBuilder: (context, child, frame, synchronous) => _fadeIn(
        context,
        child,
        frame,
        synchronous,
        _ImageFallback(width: width, height: height, profile: profile),
      ),
      errorBuilder: (_, _, _) =>
          _ImageFallback(width: width, height: height, profile: profile),
    );
  }
}
