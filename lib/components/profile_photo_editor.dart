import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/session.dart';
import '../core/profile_data.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';
import 'components.dart';
import 'attachment_sheet.dart';

enum ProfilePhotoKind { avatar, cover }

bool get _hasCamera =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

Future<XFile?> _pickPhoto(BuildContext context, ProfilePhotoKind kind) async {
  if (!_hasCamera) return ImagePicker().pickImage(source: ImageSource.gallery);
  Future<XFile?>? selection;
  await showAttachmentSheet(
    context,
    title: kind == ProfilePhotoKind.avatar
        ? context.l10n.profileSetPhoto
        : context.l10n.profileCoverPhoto,
    singlePhoto: true,
    sendLabel: context.l10n.authContinue,
    onCamera: () =>
        selection = ImagePicker().pickImage(source: ImageSource.camera),
    onLibrary: () =>
        selection = ImagePicker().pickImage(source: ImageSource.gallery),
    actions: const [],
    onSelect: (items) async {
      selection = Future.value(XFile(items.single.path));
      return true;
    },
  );
  return selection == null ? null : await selection;
}

Future<bool?> editProfilePhoto(
  BuildContext context,
  ProfilePhotoKind kind,
) async {
  try {
    final file = await _pickPhoto(context, kind);
    if (file == null || !context.mounted) return false;
    return await open<bool>(
      context,
      ProfilePhotoEditor(kind: kind, initialPhoto: file),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.uploadStatusFailed)));
    }
    return false;
  }
}

class ProfilePhotoEditor extends StatefulWidget {
  final ProfilePhotoKind kind;
  final XFile? initialPhoto;
  final Future<XFile?> Function(ImageSource source)? picker;
  const ProfilePhotoEditor({
    super.key,
    required this.kind,
    this.picker,
    this.initialPhoto,
  });

  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  final transform = TransformationController();
  ui.Image? image, original;
  int quarterTurns = 0;
  bool mirrored = false;
  final interacting = ValueNotifier<bool>(false);
  Size? viewport;
  double minimumScale = 1;
  bool picking = false, saving = false;
  String? error;
  bool get avatar => widget.kind == ProfilePhotoKind.avatar;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) choose(ImageSource.gallery, file: widget.initialPhoto);
      });
    }
  }

  @override
  void dispose() {
    transform.dispose();
    if (image != original) image?.dispose();
    original?.dispose();
    interacting.dispose();
    super.dispose();
  }

  Future<void> choose(ImageSource source, {XFile? file}) async {
    if (picking || saving) return;
    setState(() {
      picking = true;
      error = null;
    });
    ui.Codec? codec;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      file ??=
          await (widget.picker?.call(source) ??
              (source == ImageSource.gallery
                  ? _pickPhoto(context, widget.kind)
                  : ImagePicker().pickImage(source: source)));
      if (file == null || !mounted) return;
      buffer = await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        2048 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      final previous = image, previousOriginal = original;
      setState(() {
        original = image = frame.image;
        quarterTurns = 0;
        mirrored = false;
        viewport = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previous != previousOriginal) previous?.dispose();
        previousOriginal?.dispose();
      });
    } catch (_) {
      if (mounted) setState(() => error = context.l10n.uploadStatusFailed);
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> orient(int turns, bool flip) async {
    if (picking || saving || original == null) return;
    HapticFeedback.selectionClick();
    setState(() => picking = true);
    ui.Image? next;
    try {
      final source = original!;
      if (turns == 0 && !flip) {
        next = source;
      } else {
        final width = turns.isEven ? source.width : source.height;
        final height = turns.isEven ? source.height : source.width;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..translate(width / 2, height / 2)
          ..scale(flip ? -1.0 : 1.0, 1.0)
          ..rotate(turns * math.pi / 2)
          ..translate(-source.width / 2, -source.height / 2);
        canvas.drawImage(source, Offset.zero, Paint());
        final picture = recorder.endRecording();
        try {
          next = await picture.toImage(width, height);
        } finally {
          picture.dispose();
        }
      }
      if (!mounted) {
        if (next != source) next.dispose();
        return;
      }
      final previous = image;
      setState(() {
        image = next;
        quarterTurns = turns;
        mirrored = flip;
        viewport = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previous != original && previous != next) previous?.dispose();
      });
    } catch (_) {
      if (mounted) setState(() => error = context.l10n.uploadStatusFailed);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void reset(Size size) {
    final source = image!;
    minimumScale =
        math.max(size.width / source.width, size.height / source.height) *
        (1 + 1e-9);
    transform.value = Matrix4.diagonal3Values(minimumScale, minimumScale, 1)
      ..setTranslationRaw(
        (size.width - source.width * minimumScale) / 2,
        (size.height - source.height * minimumScale) / 2,
        0,
      );
    viewport = size;
  }

  void resizeViewport(Size size) {
    if (viewport == null) {
      reset(size);
      return;
    }
    final old = viewport!;
    final center = transform.toScene(old.center(Offset.zero));
    final factor = transform.value.getMaxScaleOnAxis() / minimumScale;
    minimumScale =
        math.max(size.width / image!.width, size.height / image!.height) *
        (1 + 1e-9);
    final scale = minimumScale * factor.clamp(1.0, 5.0);
    transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        (size.width / 2 - center.dx * scale).clamp(
          math.min(0.0, size.width - image!.width * scale),
          0.0,
        ),
        (size.height / 2 - center.dy * scale).clamp(
          math.min(0.0, size.height - image!.height * scale),
          0.0,
        ),
        0,
      );
    viewport = size;
  }

  Future<Uint8List> croppedBytes() async {
    final source = image!, size = viewport!;
    final origin = transform.toScene(Offset.zero);
    final end = transform.toScene(Offset(size.width, size.height));
    final crop = Rect.fromPoints(origin, end).intersect(
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    );
    final width = avatar
        ? math.max(1, math.min(1024, crop.width.round()))
        : math.max(1, (math.min(1536, crop.width) / 3).floor()) * 3;
    final height = avatar ? width : width ~/ 3;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final output = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.drawImageRect(
      source,
      crop,
      output,
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final result = await picture.toImage(width, height);
    picture.dispose();
    try {
      final bytes = await result.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Image encoding failed');
      return bytes.buffer.asUint8List();
    } finally {
      result.dispose();
    }
  }

  void zoom(double factor) {
    final size = viewport!, source = image!;
    final center = transform.toScene(Offset(size.width / 2, size.height / 2));
    final scale = minimumScale * factor;
    final x = (size.width / 2 - center.dx * scale).clamp(
      size.width - source.width * scale,
      0.0,
    );
    final y = (size.height / 2 - center.dy * scale).clamp(
      math.min(0.0, size.height - source.height * scale),
      0.0,
    );
    transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(x.toDouble(), y.toDouble(), 0);
  }

  Future<void> save() async {
    if (saving || picking || image == null || viewport == null) return;
    final session = AppScope.of(context);
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final bytes = await croppedBytes();
      final kind = widget.kind.name;
      await session.api.call(
        'user.upload_$kind',
        body: {
          kind: MultipartFile.fromBytes(
            bytes,
            filename: '$kind.png',
            contentType: DioMediaType.parse('image/png'),
          ),
        },
      );
      await session.refreshUser();
      if (mounted) {
        setState(() => saving = false);
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = context.l10n.uploadStatusFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppDesign.theme(Brightness.dark),
    child: Builder(builder: buildEditor),
  );

  Widget buildEditor(BuildContext context) {
    final l = context.l10n;
    final title = avatar ? l.profileSetPhoto : l.profileCoverPhoto;
    final busy = saving || picking;
    return PopScope(
      canPop: !saving,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: AppScaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      AppIconButton(
                        tooltip: l.cancel,
                        icon: const Icon(CupertinoIcons.xmark),
                        onPressed: saving
                            ? null
                            : () => Navigator.maybePop(context),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppDesign.font(
                            17,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      AppIconButton(
                        tooltip: l.chooseFromLibrary,
                        icon: const Icon(CupertinoIcons.photo_on_rectangle),
                        onPressed: busy
                            ? null
                            : () => choose(ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final width = math
                          .min(
                            600.0,
                            math.min(
                              box.maxWidth - AppDesign.photoCropInset * 2,
                              (box.maxHeight - AppDesign.photoCropInset * 2) *
                                  (avatar ? 1 : 3),
                            ),
                          )
                          .clamp(1.0, 600.0);
                      final size = Size(width, avatar ? width : width / 3);
                      if (image != null && viewport != size) {
                        final source = image;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && image == source && viewport != size) {
                            setState(() => resizeViewport(size));
                          }
                        });
                      }
                      return ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: SizedBox.fromSize(
                                size: size,
                                child: image == null
                                    ? avatar
                                          ? Avatar(
                                              AppScope.of(context).user,
                                              radius: width / 2,
                                            )
                                          : AppImage(
                                              source: profileCover(
                                                AppScope.of(context).user,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                    : AbsorbPointer(
                                        absorbing: busy,
                                        child: InteractiveViewer(
                                          key: const ValueKey(
                                            'profile.photo.crop',
                                          ),
                                          transformationController: transform,
                                          constrained: false,
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.topLeft,
                                          minScale: minimumScale,
                                          maxScale: minimumScale * 5,
                                          onInteractionStart: (_) =>
                                              interacting.value = true,
                                          onInteractionEnd: (_) =>
                                              interacting.value = false,
                                          child: RawImage(
                                            image: image,
                                            width: image!.width.toDouble(),
                                            height: image!.height.toDouble(),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            if (image != null)
                              IgnorePointer(
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: interacting,
                                  builder: (_, active, _) => CustomPaint(
                                    painter: _PhotoCropMask(
                                      cropSize: size,
                                      oval: avatar,
                                      grid: active,
                                    ),
                                  ),
                                ),
                              ),
                            if (picking)
                              const Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .48,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (image != null) ...[
                          Text(
                            l.profilePhotoAdjust,
                            textAlign: TextAlign.center,
                            style: AppDesign.font(13, color: Colors.white70),
                          ),
                          ValueListenableBuilder<Matrix4>(
                            valueListenable: transform,
                            builder: (context, matrix, _) => Semantics(
                              label: l.zoomIn,
                              child: Slider(
                                min: 1,
                                max: 5,
                                value:
                                    (matrix.getMaxScaleOnAxis() / minimumScale)
                                        .clamp(1.0, 5.0),
                                label:
                                    '${(matrix.getMaxScaleOnAxis() / minimumScale).toStringAsFixed(1)}×',
                                onChanged: busy ? null : zoom,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              AppIconButton(
                                key: const ValueKey('profile.photo.rotate'),
                                tooltip: l.profilePhotoRotate,
                                icon: const Icon(CupertinoIcons.rotate_left),
                                onPressed: busy
                                    ? null
                                    : () => orient(
                                        (quarterTurns + 3) % 4,
                                        mirrored,
                                      ),
                              ),
                              Flexible(
                                child: AppButton.text(
                                  onPressed: busy
                                      ? null
                                      : () {
                                          if (quarterTurns != 0 || mirrored) {
                                            orient(0, false);
                                          } else {
                                            setState(() => reset(viewport!));
                                          }
                                        },
                                  child: Text(l.reset),
                                ),
                              ),
                              AppIconButton(
                                key: const ValueKey('profile.photo.mirror'),
                                tooltip: l.profilePhotoMirror,
                                icon: const Icon(
                                  CupertinoIcons.arrow_left_right,
                                ),
                                onPressed: busy
                                    ? null
                                    : () => orient(quarterTurns, !mirrored),
                              ),
                            ],
                          ),
                        ] else if (!picking) ...[
                          AppButton(
                            onPressed: busy
                                ? null
                                : () => choose(ImageSource.gallery),
                            child: Text(l.chooseFromLibrary),
                          ),
                          if (_hasCamera)
                            AppButton.text(
                              onPressed: busy
                                  ? null
                                  : () => choose(ImageSource.camera),
                              child: Text(l.camera),
                            ),
                        ],
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppPalette.of(context).destructive,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        AppButton(
                          key: const ValueKey('profile.photo.save'),
                          expand: true,
                          solid: true,
                          variant: AppButtonVariant.accent,
                          onPressed: image == null || busy ? null : save,
                          loading: saving,
                          child: Text(l.save),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoCropMask extends CustomPainter {
  final Size cropSize;
  final bool oval, grid;
  const _PhotoCropMask({
    required this.cropSize,
    required this.oval,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cropSize.width,
      height: cropSize.height,
    );
    final crop = Path();
    if (oval) {
      crop.addOval(rect);
    } else {
      crop.addRect(rect);
    }
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(crop, Offset.zero);
    canvas.drawPath(shade, Paint()..color = AppDesign.photoCropShade);
    canvas.drawPath(
      crop,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (grid) {
      canvas.save();
      canvas.clipPath(crop);
      final line = Paint()
        ..color = Colors.white38
        ..strokeWidth = 0.5;
      for (var i = 1; i < 3; i++) {
        final x = rect.left + rect.width * i / 3;
        final y = rect.top + rect.height * i / 3;
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), line);
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), line);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PhotoCropMask old) =>
      old.cropSize != cropSize || old.oval != oval || old.grid != grid;
}
