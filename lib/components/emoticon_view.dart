import '../l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/api.dart';
import 'app_button.dart';
import 'app_image.dart';
import 'app_lottie.dart';

String webAsset(dynamic value) {
  final url = string(value);
  return Uri.parse(
    const String.fromEnvironment(
      'WEB_URL',
      defaultValue: 'https://coolvibes.lgbt',
    ),
  ).resolve(url).toString();
}

/// constants/webAssets resolveServiceMedia(): service-hosted GIF documents
/// (`/static/telegram/gifs/...`) resolve against the API host, the rest are
/// absolute provider URLs.
String serviceMedia(dynamic value) {
  final url = string(value);
  return url.startsWith('/static/') ? assetUrl(url) : url;
}

/// The one sticker/GIF document renderer (source EmoticonMedia): picker,
/// composer preview, feed and message history all draw through it.
class EmoticonView extends StatelessWidget {
  final Json document;
  final double size;

  /// GIF frame; stickers stay square at [size].
  final double? width, height;
  final double radius;
  const EmoticonView({
    super.key,
    required this.document,
    this.size = 120,
    this.width,
    this.height,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (document['kind'] == 'gif') {
      return _GifMedia(
        document: document,
        width: width ?? size,
        height: height ?? size,
        radius: radius,
      );
    }
    return _StickerMedia(document: document, size: size);
  }
}

/// StickerMedia: Lottie for .tgs/.json, an image for .webp/.png, and the
/// sticker's emoji whenever the document cannot be played (AVPlayer has no
/// WebM decoder, so iOS shows the emoji instead of an empty frame).
class _StickerMedia extends StatefulWidget {
  final Json document;
  final double size;
  const _StickerMedia({required this.document, required this.size});
  @override
  State<_StickerMedia> createState() => _StickerMediaState();
}

class _StickerMediaState extends State<_StickerMedia> {
  bool failed = false;
  @override
  void didUpdateWidget(_StickerMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document['url'] != widget.document['url']) failed = false;
  }

  void fail() {
    if (!failed && mounted) setState(() => failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final raw = string(widget.document['url']);
    final path = Uri.tryParse(raw)?.path ?? raw;
    final emoji = string(widget.document['emoji']);
    final playable =
        raw.isNotEmpty &&
        !(defaultTargetPlatform == TargetPlatform.iOS &&
            path.endsWith('.webm'));
    if (failed || !playable || widget.document['kind'] == 'emoji') {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: emoji.isNotEmpty
              ? Text(
                  emoji,
                  style: TextStyle(fontSize: size * .55),
                  textScaler: TextScaler.noScaling,
                )
              : AppSymbol.icon(
                  'face.smiling',
                  size: size * .4,
                  color: const Color(0xff8e8e93),
                  fallback: Icons.emoji_emotions_outlined,
                ),
        ),
      );
    }
    final url = webAsset(raw);
    if (path.endsWith('.tgs') || path.endsWith('.json')) {
      return AppLottie(asset: url, size: size, onError: fail);
    }
    if (path.endsWith('.webm')) {
      return _LoopingVideo(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        onError: fail,
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) => fail());
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// GifMedia: provider GIF/MP4 documents with their own aspect, a neutral wash
/// while loading and the bubble's inner corner.
class _GifMedia extends StatelessWidget {
  final Json document;
  final double width, height, radius;
  const _GifMedia({
    required this.document,
    required this.width,
    required this.height,
    required this.radius,
  });
  @override
  Widget build(BuildContext context) {
    final url = serviceMedia(document['url']);
    final video = RegExp(r'\.mp4(?:$|\?)').hasMatch(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: const Color(0x1f7f7f7f),
        child: video
            ? _LoopingVideo(
                url: url,
                width: width,
                height: height,
                fit: BoxFit.cover,
              )
            : AppImage(
                source: url,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

/// A muted looping player that pauses with Reduce Motion and off-screen.
class _LoopingVideo extends StatefulWidget {
  final String url;
  final double width, height;
  final BoxFit fit;
  final VoidCallback? onError;
  const _LoopingVideo({
    required this.url,
    required this.width,
    required this.height,
    required this.fit,
    this.onError,
  });
  @override
  State<_LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends State<_LoopingVideo> {
  late VideoPlayerController controller = _create();
  bool ready = false;

  VideoPlayerController _create() {
    final value = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    value
        .initialize()
        .then((_) {
          if (!mounted) return;
          value
            ..setLooping(true)
            ..setVolume(0);
          setState(() => ready = true);
          playback();
        })
        .catchError((Object _) {
          widget.onError?.call();
        });
    return value;
  }

  void playback() {
    if (!ready || !mounted) return;
    if (TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context)) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    playback();
  }

  @override
  void didUpdateWidget(_LoopingVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      controller.dispose();
      ready = false;
      controller = _create();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: !ready
        ? null
        : FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
  );
}

/// Accessible name of a sticker/GIF document (chat list, reply, pinned bar).
String emoticonLabel(BuildContext context, Json emoticon) =>
    emoticon['kind'] == 'gif'
    ? 'GIF'
    : '${context.l10n.sticker} ${string(emoticon['emoji'])}'.trim();
