import '../l10n/l10n.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/api.dart';
import '../design/app_design.dart';
import 'app_button.dart';
import 'glass_surface.dart';
import 'screen_status.dart';

class GameMapController {
  _GameMapState? _state;
  bool get isReady => _state?.ready ?? false;
  Future<void> zoomBy(int delta) async =>
      _state?.command('zoomBy', [delta, _state!.motion ? 250 : 0]);
  Future<void> flyTo(
    double latitude,
    double longitude, {
    double zoom = 16.5,
  }) async => _state?.command('flyTo', [
    latitude,
    longitude,
    zoom,
    _state!.motion ? 600 : 0,
  ]);
}

/// Uses the original GameMapView's generated HTML/CSS/MapLibre document. There
/// is one renderer for nearby, check-ins, location selection and message maps.
class GameMap extends StatefulWidget {
  final GameMapController? controller;
  final double latitude, longitude, zoom, pitch, bearing;
  final List<Json> markers;
  final Json? player;
  final bool preview, interactive, controls;
  final bool snapshotOnly;

  /// Whether this map supplies the backdrop for floating controls.
  final bool hostsGlass;
  final double? controlsBottom;
  final ValueChanged<Json>? onMove;

  /// A camera move began; `true` when the user's gesture started it.
  final ValueChanged<bool>? onMoveStart;
  final ValueChanged<String>? onMarker;
  final VoidCallback? onPress;
  const GameMap({
    super.key,
    this.controller,
    this.latitude = 41.0082,
    this.longitude = 28.9784,
    this.zoom = 16.5,
    this.pitch = 65,
    this.bearing = -20,
    this.markers = const [],
    this.player,
    this.preview = false,
    this.interactive = true,
    this.controls = true,
    this.hostsGlass = true,
    this.snapshotOnly = false,
    this.controlsBottom,
    this.onMove,
    this.onMoveStart,
    this.onMarker,
    this.onPress,
  });
  @override
  State<GameMap> createState() => _GameMapState();
}

class _GameMapState extends State<GameMap> {
  WebViewController? web;
  bool ready = false, configured = false;
  final pending = <String, List<dynamic>>{};
  String? error;
  Timer? bootTimer;
  int loadVersion = 0;
  ui.Image? previewImage;
  bool decodingPreview = false;
  bool? darkAppearance;
  bool get motion => mounted && !MediaQuery.disableAnimationsOf(context);
  Future<void> command(String method, List<dynamic> args) async {
    if (!ready || web == null) {
      pending[method] = args;
      return;
    }
    await web!.runJavaScript(
      'window.__gameMap && window.__gameMap.$method(${args.map((v) => jsonEncode(v).replaceAll('<', r'\u003c')).join(',')});',
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  /// Registered with PlatformBackdrop while this map's tab/route is active,
  /// so glass drawn over it takes the backdrop path.
  void syncBackdrop(bool visible) {
    final showing = visible && widget.hostsGlass;
    // Notified after the frame: listeners rebuild outside this build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => PlatformBackdrop.set(this, showing && mounted),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncBackdrop(TickerMode.valuesOf(context).enabled);
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!configured || (widget.snapshotOnly && darkAppearance != dark)) {
      configured = true;
      darkAppearance = dark;
      load();
    }
  }

  Future<void> load() async {
    final version = ++loadVersion;
    bootTimer?.cancel();
    final dark = Theme.of(context).brightness == Brightness.dark;
    setState(() {
      error = null;
      ready = false;
      final previous = previewImage;
      previewImage = null;
      decodingPreview = false;
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    });
    try {
      final palette = object(
        jsonDecode(
          await rootBundle.loadString(
            'assets/map/palette-${dark ? 'night' : 'day'}.json',
          ),
        ),
      );
      final template = await rootBundle.loadString('assets/map/game-map.html');
      final init = {
        'preview': widget.preview,
        'snapshot': widget.snapshotOnly,
        'snapshotOnly': widget.snapshotOnly,
        'center': [widget.longitude, widget.latitude],
        'zoom': widget.zoom,
        'pitch': widget.preview ? 0 : widget.pitch,
        'bearing': widget.preview ? 0 : widget.bearing,
        'markers': widget.markers,
        'player': widget.player,
        'interactive': {
          'pan': widget.interactive,
          'zoom': widget.interactive,
          'rotate': widget.interactive && !widget.preview,
          'pitch': widget.interactive && !widget.preview,
        },
        'colors': palette,
        'appearance': {'dark': dark, 'opaque': false},
      };
      if (!mounted || version != loadVersion) return;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'CoolvibesMap',
          onMessageReceived: (message) {
            if (!mounted || version != loadVersion) return;
            try {
              final event = object(jsonDecode(message.message));
              switch (event['type']) {
                case 'ready':
                  if (!widget.snapshotOnly) bootTimer?.cancel();
                  setState(() {
                    ready = !widget.snapshotOnly;
                    error = null;
                  });
                  final queued = {...pending};
                  pending.clear();
                  for (final call in queued.entries) {
                    command(call.key, call.value);
                  }
                  break;
                case 'snapshot':
                  if (widget.snapshotOnly) receivePreview(event, version);
                  break;
                case 'maperror':
                  setState(() => error = context.l10n.mapCouldNotLoadCheckYour);
                  break;
                case 'movestart':
                  widget.onMoveStart?.call(event['user'] == true);
                  break;
                case 'moveend':
                  widget.onMove?.call(event);
                  break;
                case 'marker':
                  widget.onMarker?.call(string(event['id']));
                  break;
                case 'press':
                  widget.onPress?.call();
                  break;
              }
            } catch (_) {}
          },
        )
        ..loadHtmlString(
          template
              .replaceAll(
                '__COOLVIBES_INIT_JSON__',
                jsonEncode(init).replaceAll('<', r'\u003c'),
              )
              .replaceAll(
                '__COOLVIBES_BG_COLOR__',
                string((palette['ground'] as List).first),
              ),
          baseUrl: 'https://coolvibes.lgbt/',
        );
      setState(() => web = controller);
      bootTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && !ready && version == loadVersion) {
          setState(() => error = context.l10n.mapCouldNotLoadCheckYour);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = context.l10n.mapIsUnavailableOnThisDevice);
      }
    }
  }

  Future<void> receivePreview(Json event, int version) async {
    if (decodingPreview || previewImage != null) return;
    final data = string(event['data']);
    if (!data.startsWith('data:image/jpeg;base64,') || data.length > 8000000) {
      return;
    }
    decodingPreview = true;
    try {
      final codec = await ui.instantiateImageCodec(
        base64Decode(data.substring(data.indexOf(',') + 1)),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted || version != loadVersion) {
        frame.image.dispose();
        return;
      }
      bootTimer?.cancel();
      setState(() {
        previewImage = frame.image;
        web = null;
        ready = true;
        error = null;
      });
    } catch (_) {
      if (mounted && version == loadVersion) {
        setState(() => error = context.l10n.mapCouldNotLoadCheckYour);
      }
    } finally {
      if (version == loadVersion) decodingPreview = false;
    }
  }

  @override
  void didUpdateWidget(GameMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (oldWidget.markers != widget.markers) {
      command('setMarkers', [widget.markers]);
    }
    if (oldWidget.player != widget.player) {
      command('setPlayer', [widget.player]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => PlatformBackdrop.set(this, false),
    );
    bootTimer?.cancel();
    previewImage?.dispose();
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (web != null)
        Positioned.fill(
          child: Opacity(
            // A nonzero 8-bit alpha keeps the platform view attached to its window.
            opacity: widget.snapshotOnly ? .02 : 1,
            child: WebViewWidget(
              controller: web!,
              gestureRecognizers: widget.interactive
                  ? {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    }
                  : const {},
            ),
          ),
        ),
      if (widget.snapshotOnly)
        Positioned.fill(
          child: previewImage == null
              ? ColoredBox(color: AppPalette.of(context).row)
              : RawImage(
                  image: previewImage,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
        ),
      if (error != null)
        Center(
          child: ScreenStatus(error: error, retry: load, compact: true),
        ),
      if (!ready && error == null)
        const Center(child: CircularProgressIndicator.adaptive()),
      if (widget.controls && ready)
        // MapZoomControls: one 48pt glass capsule, + over − split by a
        // hairline, 16pt from the trailing edge like the map's 48pt circles.
        PositionedDirectional(
          end: 16,
          bottom:
              widget.controlsBottom ??
              MediaQuery.paddingOf(context).bottom + 16,
          child: GlassSurface(
            radius: 24,
            interactive: true,
            child: SizedBox(
              width: 48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    dimension: 48,
                    glass: false,
                    color: AppPalette.of(context).text,
                    tooltip: context.l10n.zoomIn,
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      command('zoomBy', [1, motion ? 250 : 0]);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      height: 1 / MediaQuery.devicePixelRatioOf(context),
                      color: AppPalette.of(context).border,
                    ),
                  ),
                  AppIconButton(
                    dimension: 48,
                    glass: false,
                    color: AppPalette.of(context).text,
                    tooltip: context.l10n.zoomOut,
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      command('zoomBy', [-1, motion ? 250 : 0]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
