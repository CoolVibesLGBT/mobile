import '../l10n/l10n.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/glass_surface.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';
import 'package:video_player/video_player.dart';
import '../core/api.dart';
import '../core/audio_source.dart';
import '../core/session.dart';
import '../components/components.dart';

List<Json> mediaOf(Json record) {
  // The first non-empty list: chat rows carry `media: []` beside their
  // `attachments` (ChatDetail toMessage reads `attachments`).
  final raw = [
    record['media'],
    record['attachments'],
    record['photos'],
  ].firstWhere((v) => v is List && v.isNotEmpty, orElse: () => null);
  if (raw is List) {
    return raw
        .map((m) => m is String ? <String, dynamic>{'url': m} : object(m))
        .toList();
  }
  if (record['url'] != null ||
      record['media_url'] != null ||
      record['file'] != null) {
    return [record];
  }
  return [];
}

String mediaUrl(Json item) => string(item['localPath']).isNotEmpty
    ? string(item['localPath'])
    : assetUrl(item['media_url'] ?? item['file_url'] ?? item);
String mediaMime(Json item) => string(
  object(item['file'])['mime_type'] ?? item['mime_type'] ?? item['mime'],
).toLowerCase();
bool audioMedia(Json item) =>
    mediaMime(item).startsWith('audio/') ||
    RegExp(r'\.(m4a|mp3|wav|ogg)(\?|$)').hasMatch(mediaUrl(item));
bool documentMedia(Json item) {
  final mime = mediaMime(item);
  return mime.isNotEmpty &&
          !mime.startsWith('image/') &&
          !mime.startsWith('video/') &&
          !audioMedia(item) ||
      RegExp(r'\.(pdf|zip|txt|docx?|xlsx?)(\?|$)').hasMatch(mediaUrl(item));
}

/// The one media strip for posts and chat messages. [aspect] sets the frame
/// (PostCard: a square card-width pager with a count pill and page dots;
/// ChatMessageRow: width x .8). [onTap] defaults to the media viewer.
class MediaAttachments extends StatefulWidget {
  final Json record;
  final double? width;
  final double aspect;
  final bool indicators;
  final VoidCallback? onTap;
  const MediaAttachments({
    super.key,
    required this.record,
    this.width,
    this.aspect = 1,
    this.indicators = false,
    this.onTap,
  });
  @override
  State<MediaAttachments> createState() => _MediaAttachmentsState();
}

class _MediaAttachmentsState extends State<MediaAttachments> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final media = mediaOf(widget.record);
    if (media.isEmpty) return const SizedBox.shrink();
    if (media.length == 1 &&
        (audioMedia(media.single) || documentMedia(media.single))) {
      return MediaItem(item: media.single, preview: true);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final width = widget.width ?? box.maxWidth;
        final height = width * widget.aspect;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: media.length,
                onPageChanged: (value) => setState(() => page = value),
                itemBuilder: (context, i) => GestureDetector(
                  onTap:
                      widget.onTap ??
                      () =>
                          MediaScreen.show(context, widget.record, initial: i),
                  child: ColoredBox(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xff1f1f1f)
                        : const Color(0xfff9f9f9),
                    child: MediaItem(item: media[i], preview: true),
                  ),
                ),
              ),
              if (widget.indicators && media.length > 1) ...[
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x8f000000),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '${page + 1}/${media.length}',
                      style: AppDesign.font(
                        12,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < media.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == page ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == page
                                ? Colors.white
                                : const Color(0x73ffffff),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class MediaScreen extends StatefulWidget {
  final Json record;
  final int initial;
  const MediaScreen({super.key, required this.record, this.initial = 0});

  /// GalleryController presentation: a non-opaque route that fades in over
  /// the source, so a downward drag reveals it while dismissing.
  static Future<void> show(
    BuildContext context,
    Json record, {
    int initial = 0,
  }) => Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: null,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => MediaScreen(record: record, initial: initial),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: MediaQuery.disableAnimationsOf(context)
            ? kAlwaysCompleteAnimation
            : CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  late final pages = PageController(initialPage: widget.initial);
  late int page = widget.initial;
  bool chrome = true;
  double drag = 0;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  /// GalleryPagerNode dismiss: past 100pt or a fast flick closes, otherwise
  /// the item springs back.
  void endDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (drag.abs() > 100 || velocity.abs() > 1000) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.record['_private'] == true &&
        widget.record['_revision'] != AppScope.of(context).mediaRevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const AppScaffold(body: ScreenStatus(loading: true));
    }
    final media = mediaOf(widget.record);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final height = MediaQuery.sizeOf(context).height;
    final fade = (1 - drag.abs() / (height / 2)).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.black.withValues(alpha: fade),
        child: Stack(
          children: [
            Positioned.fill(
              child: media.isEmpty
                  ? const ScreenStatus()
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => chrome = !chrome),
                      onVerticalDragUpdate: (d) =>
                          setState(() => drag += d.delta.dy),
                      onVerticalDragEnd: endDrag,
                      child: AnimatedContainer(
                        duration: drag == 0 && !reduced
                            ? const Duration(milliseconds: 200)
                            : Duration.zero,
                        curve: Curves.easeOut,
                        transform: Matrix4.translationValues(0, drag, 0),
                        child: PageView.builder(
                          controller: pages,
                          itemCount: media.length,
                          onPageChanged: (value) =>
                              setState(() => page = value),
                          itemBuilder: (_, i) => MediaItem(item: media[i]),
                        ),
                      ),
                    ),
            ),
            // Gallery navigation bar: back control and "n of m".
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: !chrome,
                child: AnimatedOpacity(
                  opacity: chrome && drag == 0 ? 1 : 0,
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: AppHeader(
                    edge: AppHeaderEdge.none,
                    foregroundColor: Colors.white,
                    title: media.length > 1
                        ? Text(context.l10n.ofLabel(page + 1, media.length))
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MediaItem extends StatelessWidget {
  final Json item;
  final bool preview;
  const MediaItem({super.key, required this.item, this.preview = false});
  @override
  Widget build(BuildContext context) {
    final url = mediaUrl(item);
    final file = object(item['file']);
    final local = string(item['localPath']).isNotEmpty;
    if (audioMedia(item)) return AudioMediaPlayer(item: item);
    if (documentMedia(item)) return _DocumentMedia(item: item);
    final video =
        item['type'] == 'video' ||
        string(file['mime_type']).startsWith('video/') ||
        RegExp(r'\.(mp4|mov)(\?|$)').hasMatch(url);
    if (video) {
      return preview
          ? const Center(child: Icon(Icons.play_circle, size: 64))
          : VideoView(url: url, local: local);
    }
    final image = Center(
      child: AppImage(
        source: item['localAsset'] != null
            ? AssetImage(string(item['localAsset']))
            : local
            ? FileImage(File(url))
            : url,
      ),
    );
    return preview ? image : InteractiveViewer(child: image);
  }
}

class VideoView extends StatefulWidget {
  final String url;
  final bool local;
  const VideoView({super.key, required this.url, this.local = false});
  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late final controller = widget.local
      ? VideoPlayerController.file(File(widget.url))
      : VideoPlayerController.networkUrl(
          Uri.parse(widget.url),
          httpHeaders:
              context
                  .getInheritedWidgetOfExactType<AppScope>()
                  ?.notifier
                  ?.api
                  .mediaHeaders(widget.url) ??
              const {},
        );
  String? error;
  @override
  void initState() {
    super.initState();
    controller
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object e) {
          if (mounted) setState(() => error = '$e');
        });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null || !controller.value.isInitialized) {
      return ScreenStatus(loading: error == null, error: error);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        VideoProgressIndicator(controller, allowScrubbing: true),
        AppIconButton(
          color: Colors.white,
          tooltip: context.l10n.playPause,
          onPressed: () => setState(
            () => controller.value.isPlaying
                ? controller.pause()
                : controller.play(),
          ),
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
        ),
      ],
    );
  }
}

class _DocumentMedia extends StatelessWidget {
  final Json item;
  const _DocumentMedia({required this.item});
  Future<void> show(BuildContext context) => perform(context, () async {
    final local = string(item['localPath']);
    if (local.isNotEmpty) {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(local)],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } else if (!await launchUrl(
      Uri.parse(mediaUrl(item)),
      mode: LaunchMode.inAppBrowserView,
    )) {
      if (context.mounted) {
        throw ApiException(context.l10n.couldNotOpenFile);
      }
    }
  });
  @override
  Widget build(BuildContext context) {
    final file = object(item['file']);
    final name = string(file['name'] ?? item['name']);
    final size = num.tryParse(string(file['size'] ?? item['size']));
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68, maxWidth: 280),
      child: AppRow(
        leading: GlassSurface(
          radius: 22,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(
              Icons.description_outlined,
              size: 25,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        title: Text(
          name.isEmpty ? context.l10n.file : name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          [
            mediaMime(item),
            if (size != null) '${(size / 1024).ceil()} KB',
          ].where((v) => v.isNotEmpty).join(' · '),
          style: const TextStyle(fontSize: 13),
        ),
        onTap: () => show(context),
      ),
    );
  }
}

/// Bubble colours for a voice message (ChatMessageInteractiveFileNode):
/// mediaActiveControlColor fills the play control and the played bars,
/// mediaInactiveControlColor the rest; the glyph takes the bubble fill.
class VoiceBubbleStyle {
  final Color active, inactive, glyph, duration;

  /// The bubble's date/status, drawn on the duration row.
  final Widget? meta;

  /// The widest content the bubble allows (Telegram's constrainedSize).
  final double maxWidth;
  const VoiceBubbleStyle({
    required this.active,
    required this.inactive,
    required this.glyph,
    required this.duration,
    required this.maxWidth,
    this.meta,
  });
}

class AudioMediaPlayer extends StatefulWidget {
  final Json item;
  final bool compact;

  /// Draws Telegram's voice-message bubble content instead of the card.
  final VoiceBubbleStyle? voice;
  const AudioMediaPlayer({
    super.key,
    required this.item,
    this.compact = false,
    this.voice,
  });
  @override
  State<AudioMediaPlayer> createState() => _AudioMediaPlayerState();
}

class _AudioMediaPlayerState extends State<AudioMediaPlayer>
    with WidgetsBindingObserver {
  AudioPlayer? player;
  PositionUpdater? positionUpdater;
  AudioSourceLoader? audioSource;
  Future<void>? preparation;
  int generation = 0;
  final subscriptions = <StreamSubscription>[];
  Duration duration = Duration.zero, position = Duration.zero;
  bool playing = false, busy = false, loaded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    probeDuration();
  }

  void probeDuration() {
    if (widget.voice != null && knownDuration == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => probe());
    }
  }

  @override
  void didUpdateWidget(AudioMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mediaUrl(oldWidget.item) != mediaUrl(widget.item) ||
        mediaMime(oldWidget.item) != mediaMime(widget.item)) {
      releasePlayer();
      duration = position = Duration.zero;
      playing = busy = loaded = false;
      error = null;
      probeDuration();
    }
  }

  Duration get knownDuration => duration > Duration.zero
      ? duration
      : Duration(
          milliseconds:
              ((((widget.item['duration'] ??
                                      object(widget.item['file'])['duration'])
                                  as num?) ??
                              0)
                          .toDouble() *
                      1000)
                  .round(),
        );

  AudioPlayer ensurePlayer() {
    final current = player;
    if (current != null) return current;
    final next = player = AudioPlayer();
    final currentGeneration = generation;
    bool active() => mounted && currentGeneration == generation;
    void failed(Object failure) {
      if (active()) playbackFailed(failure);
    }

    next.positionUpdater = positionUpdater = TimerPositionUpdater(
      interval: const Duration(milliseconds: 200),
      getPosition: () async {
        if (!active()) return null;
        try {
          final value = await next.getCurrentPosition();
          return active() ? value : null;
        } catch (failure) {
          failed(failure);
          return null;
        }
      },
    );
    subscriptions.addAll([
      next.onPlayerStateChanged.listen((value) {
        if (active()) setState(() => playing = value == PlayerState.playing);
      }, onError: failed),
      next.onDurationChanged.listen((value) {
        if (active()) setState(() => duration = value);
      }, onError: failed),
      next.onPositionChanged.listen((value) {
        if (active()) setState(() => position = value);
      }, onError: failed),
      next.onPlayerComplete.listen((_) {
        if (active()) {
          setState(() {
            playing = false;
            loaded = false;
            position = Duration.zero;
          });
        }
      }, onError: failed),
    ]);
    return next;
  }

  void playbackFailed(Object failure) {
    if (!mounted) return;
    positionUpdater?.stop();
    setState(() {
      playing = loaded = false;
      error = context.l10n.audioCouldNotBePlayed;
    });
  }

  Future<void> prepare() async {
    if (loaded || !mounted) return;
    final pending = preparation ??= prepareSource();
    try {
      await pending;
    } finally {
      if (identical(preparation, pending)) preparation = null;
    }
  }

  Future<void> prepareSource() async {
    final currentGeneration = generation;
    final loader = audioSource ??= AudioSourceLoader(
      api: context.getInheritedWidgetOfExactType<AppScope>()?.notifier?.api,
      url: mediaUrl(widget.item),
      localPath: string(widget.item['localPath']),
      mimeType: mediaMime(widget.item).isEmpty ? null : mediaMime(widget.item),
    );
    final source = await loader.load();
    if (!mounted || currentGeneration != generation) return;
    final next = ensurePlayer();
    await next.setSource(source);
    final value = await next.getDuration();
    if (!mounted || currentGeneration != generation) return;
    setState(() {
      if (value != null && value > Duration.zero) duration = value;
      loaded = true;
    });
  }

  /// Reads the length without playing (metadata only).
  Future<void> probe() async {
    if (!mounted || loaded) return;
    try {
      await prepare();
    } catch (_) {
      /* The duration stays unknown until playback. */
    }
  }

  Future<void> seekTo(double fraction) async {
    final total = knownDuration;
    if (total == Duration.zero) return;
    final target = total * fraction.clamp(0.0, 1.0);
    setState(() => position = target);
    if (!loaded) return;
    final currentGeneration = generation;
    try {
      await player?.seek(target);
    } catch (failure) {
      if (currentGeneration == generation) playbackFailed(failure);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  Future<void> pause() async {
    final currentGeneration = generation;
    try {
      await player?.pause();
    } catch (failure) {
      if (currentGeneration == generation) playbackFailed(failure);
    }
  }

  Future<void> toggle() async {
    if (busy || !mounted) return;
    final currentGeneration = generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (playing) {
        await pause();
      } else {
        await prepare();
        if (!mounted || currentGeneration != generation) return;
        final next = player;
        if (next == null) return;
        if (position > Duration.zero) await next.seek(position);
        if (!mounted || currentGeneration != generation) return;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
          await next.resume();
        }
      }
    } catch (failure) {
      if (currentGeneration == generation) playbackFailed(failure);
    } finally {
      if (mounted && currentGeneration == generation) {
        setState(() => busy = false);
      }
    }
  }

  void releasePlayer() {
    generation++;
    positionUpdater?.stop();
    positionUpdater = null;
    final previousPlayer = player;
    final previousSource = audioSource;
    final pending = preparation;
    final listeners = List<StreamSubscription>.of(subscriptions);
    player = null;
    audioSource = null;
    preparation = null;
    subscriptions.clear();
    previousSource?.cancel();
    unawaited(
      () async {
        try {
          await pending;
        } catch (_) {
          // A cancelled preparation must finish before releasing AVPlayer.
        }
        await Future.wait(
          listeners.map((subscription) => subscription.cancel()),
        );
        try {
          await previousPlayer?.dispose();
        } catch (_) {
          // A failed native source can also fail during release.
        } finally {
          await previousSource?.dispose();
        }
      }().catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    releasePlayer();
    super.dispose();
  }

  /// ChatMessageInteractiveFileNode, voice: 38pt content inside the file
  /// insets (15, 9, 15, 12); width grows with the length.
  Widget _voice(BuildContext context, VoiceBubbleStyle style) {
    final total = knownDuration;
    final seconds = total.inMilliseconds / 1000;
    final maxWidth = style.maxWidth - 36;
    final width = math.max(
      AppDesign.voiceMinWidth,
      AppDesign.voiceMinWidth +
          (maxWidth - AppDesign.voiceMinWidth) *
              (seconds.clamp(2.0, 30.0) - 2) /
              28,
    );
    final progress = total == Duration.zero
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final waveform = [
      for (final v
          in widget.item['waveform'] is List
              ? widget.item['waveform'] as List
              : const [])
        if (v is num) v.toDouble(),
    ];
    final shown = playing || position > Duration.zero ? position : total;
    final name = string(
      object(widget.item['file'])['name'] ?? widget.item['name'],
    );
    return Semantics(
      label: name.isEmpty ? context.l10n.voiceMessage : name,
      value: time(shown),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(7, 13, 10, 13),
        child: SizedBox(
          width: width,
          height: AppDesign.voiceHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // progressFrame: 44pt at (3, -3).
              PositionedDirectional(
                start: 3,
                top: -3,
                child: AppPressable(
                  label: playing ? context.l10n.pause : context.l10n.play,
                  style: AppPressStyle.iconButton,
                  onPressed: busy ? null : toggle,
                  child: Container(
                    width: AppDesign.voiceControl,
                    height: AppDesign.voiceControl,
                    decoration: BoxDecoration(
                      color: style.active,
                      shape: BoxShape.circle,
                    ),
                    child: busy
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: style.glyph,
                            ),
                          )
                        : Icon(
                            playing
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            size: 22,
                            color: style.glyph,
                          ),
                  ),
                ),
              ),
              // scrubbingFrame: x 57, y 1, width − 60, 18pt.
              PositionedDirectional(
                start: 57,
                top: 1,
                width: width - 60,
                height: AppDesign.waveformPeak,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final rtl = Directionality.of(context) == TextDirection.rtl;
                    double at(Offset local) {
                      final f = local.dx / box.maxWidth;
                      return rtl ? 1 - f : f;
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => seekTo(at(d.localPosition)),
                      onHorizontalDragUpdate: (d) =>
                          seekTo(at(d.localPosition)),
                      child: Transform.flip(
                        flipX: rtl,
                        child: CustomPaint(
                          size: Size(box.maxWidth, AppDesign.waveformPeak),
                          painter: VoiceWaveformPainter(
                            samples: waveform,
                            progress: progress,
                            active: style.active,
                            inactive: style.inactive,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // descriptionFrame (56, 22): duration, 11/17 of the base size.
              PositionedDirectional(
                start: 56,
                top: 22,
                child: Text(
                  error ?? time(shown),
                  textScaler: TextScaler.noScaling,
                  style:
                      AppDesign.font(
                        11 * MediaQuery.textScalerOf(context).scale(1),
                        color: error == null
                            ? style.duration
                            : AppPalette.of(context).destructive,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              if (style.meta != null)
                PositionedDirectional(end: -4, top: 22, child: style.meta!),
            ],
          ),
        ),
      ),
    );
  }

  String time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final name = string(
      object(widget.item['file'])['name'] ?? widget.item['name'],
    );
    final voice = widget.voice;
    if (voice != null) return _voice(context, voice);
    if (widget.compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppIconButton(
                embedded: true,
                tooltip: playing ? context.l10n.pause : context.l10n.play,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator.adaptive(),
                      )
                    : Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: busy ? null : toggle,
              ),
              Expanded(
                child: Slider(
                  value: position.inMilliseconds.toDouble().clamp(
                    0,
                    duration.inMilliseconds.toDouble(),
                  ),
                  max: duration.inMilliseconds > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1,
                  onChanged: duration > Duration.zero
                      ? (v) => seekTo(v / duration.inMilliseconds)
                      : null,
                ),
              ),
              Text(
                time(
                  duration > Duration.zero
                      ? duration
                      : Duration(
                          seconds:
                              (widget.item['duration'] as num?)?.toInt() ?? 0,
                        ),
                ),
                style: AppDesign.font(
                  13,
                  color: AppPalette.of(context).secondaryLabel,
                ),
              ),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: AppDesign.font(
                13,
                color: AppPalette.of(context).destructive,
              ),
            ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: GlassSurface(
        radius: 12,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AppIconButton(
                    tooltip: (playing ? context.l10n.pause : context.l10n.play),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: busy ? null : toggle,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? context.l10n.voiceMessage : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5,
                            ),
                          ),
                          child: Slider(
                            value: position.inMilliseconds.toDouble().clamp(
                              0,
                              duration.inMilliseconds.toDouble(),
                            ),
                            max: duration.inMilliseconds > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1,
                            onChanged: duration > Duration.zero
                                ? (value) =>
                                      seekTo(value / duration.inMilliseconds)
                                : null,
                          ),
                        ),
                        Text(
                          '${time(position)}${duration > Duration.zero ? ' / ${time(duration)}' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AudioWaveformComponent (.bottom): 2pt bars 2pt apart, heights scaled to
/// the loudest sample over an 18pt peak minus 1.5 bar widths, round caps,
/// and each bar mixed from the inactive to the active colour as playback
/// crosses it. Without samples every bar is a 2pt dot, as in Telegram.
class VoiceWaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color active, inactive;
  const VoiceWaveformPainter({
    required this.samples,
    required this.progress,
    required this.active,
    required this.inactive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bar = AppDesign.waveformBar, half = bar / 2;
    final count = (size.width / (bar + AppDesign.waveformGap)).floor();
    if (count <= 0) return;
    final bins = List<double>.filled(count, 0);
    for (var i = 0; i < samples.length; i++) {
      final index = (i * count / samples.length).floor().clamp(0, count - 1);
      if (bins[index] < samples[i]) bins[index] = samples[i];
    }
    final peak = samples.fold<double>(0, math.max);
    final paint = Paint()..isAntiAlias = true;
    for (var i = 0; i < count; i++) {
      final start = i / count, next = (i + 1) / count;
      final mix = progress > start
          ? ((progress - start) / (next - start)).clamp(0.0, 1.0)
          : 0.0;
      paint.color = Color.lerp(inactive, active, mix)!;
      final x = i * (bar + AppDesign.waveformGap);
      var height = peak <= 0 ? 0.0 : bins[i] / peak * AppDesign.waveformPeak;
      if (height > AppDesign.waveformPeak) height = AppDesign.waveformPeak;
      final adjusted = height - bar * 1.5;
      if (adjusted <= bar) {
        canvas.drawOval(Rect.fromLTWH(x, size.height - bar, bar, bar), paint);
      } else {
        final rect = Rect.fromLTWH(
          x,
          size.height - adjusted,
          bar,
          adjusted - half,
        );
        canvas.drawOval(Rect.fromLTWH(x, rect.top - half, bar, bar), paint);
        canvas.drawOval(Rect.fromLTWH(x, rect.bottom - half, bar, bar), paint);
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(VoiceWaveformPainter old) =>
      old.progress != progress ||
      old.samples != samples ||
      old.active != active ||
      old.inactive != inactive;
}
