import '../l10n/l10n.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/attachments.dart';
import '../core/api.dart';
import '../screens/drawing.dart';
import '../screens/emoticons.dart';
import '../screens/media.dart' show AudioMediaPlayer;
import '../screens/location_picker.dart';
import 'components.dart';
import 'glass_surface.dart';
import '../design/app_design.dart';
import 'attachment_sheet.dart';
import 'emoticon_view.dart';
import 'location_attachment.dart';

/// Opens the attachment sheet. In a chat ([sendNow]) gallery picks are sent
/// at once, like Telegram; composers add them to the draft.
Future<void> chooseAttachment(
  BuildContext context,
  AttachmentController controller, {
  Future<void> Function()? sendNow,
}) => showAttachmentSheet(
  context,
  sendLabel: sendNow != null ? context.l10n.send : context.l10n.add,
  allowSpoiler: sendNow != null,
  onCamera: () => perform(context, () => controller.pickImages(camera: true)),
  onLibrary: () => perform(context, controller.pickImages),
  actions: [
    AttachmentAction(
      id: 'file',
      label: context.l10n.file,
      symbol: 'doc',
      fallback: Icons.insert_drive_file_outlined,
      onPressed: () => perform(context, controller.pickDocuments),
    ),
    AttachmentAction(
      id: 'location',
      label: context.l10n.location,
      symbol: 'mappin.and.ellipse',
      fallback: Icons.location_on_outlined,
      onPressed: () => pickLocation(context, controller, sendNow: sendNow),
    ),
  ],
  onSelect: (picks) async {
    try {
      for (final pick in picks) {
        await controller.addFile(
          pick.path,
          name: pick.name,
          contentType: pick.mime,
        );
      }
      if (picks.any((pick) => pick.spoiler)) controller.spoiler = true;
      if (sendNow != null) await sendNow();
      return true;
    } catch (_) {
      return false;
    }
  },
);

/// One selection/return owner for the menu and draft preview editing. In a
/// chat ([sendNow]) the pick is sent at once, like Telegram's
/// `interaction.sendLocation`; composers keep it in the draft.
Future<void> pickLocation(
  BuildContext context,
  AttachmentController controller, {
  Future<void> Function()? sendNow,
}) async {
  final location = await sheet<Json>(
    context,
    LocationPickerScreen(initial: controller.location),
  );
  if (location != null && !controller.disposed) {
    controller.location = location;
    controller.changed();
    if (sendNow != null) await sendNow();
  }
}

/// Kept for the drawing and sticker entry points used by other screens.
Future<void> openDrawing(
  BuildContext context,
  AttachmentController controller,
) async {
  final path = await sheet<String>(context, const DrawingScreen());
  if (path != null) {
    await controller.addFile(
      path,
      name: 'Drawing.png',
      contentType: 'image/png',
    );
  }
}

Future<void> openEmoticons(
  BuildContext context,
  AttachmentController controller,
) async {
  final emoticon = await EmoticonPicker.show(context);
  if (emoticon != null) {
    controller.emoticon = emoticon;
    controller.changed();
  }
}

class AttachmentPreview extends StatelessWidget {
  final AttachmentController controller;
  const AttachmentPreview({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.recording)
          VoiceRecordingBar(
            controller: controller,
            onCancel: () =>
                perform(context, () => controller.stopRecording(cancel: true)),
            onStop: () => perform(context, controller.stopRecording),
          ),
        for (final file in controller.files.where(
          (f) => '${f['mime']}'.startsWith('audio/'),
        ))
          Row(
            children: [
              AppIconButton(
                embedded: true,
                tooltip: context.l10n.remove,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => controller.remove(file),
              ),
              Expanded(
                child: AudioMediaPlayer(
                  key: ValueKey(file['path']),
                  compact: true,
                  item: {...file, 'localPath': file['path']},
                ),
              ),
            ],
          ),
        if (controller.files.any((f) => !'${f['mime']}'.startsWith('audio/')) ||
            controller.location != null ||
            controller.emoticon != null)
          SizedBox(
            height: controller.location == null
                ? 130
                : (150 + MediaQuery.textScalerOf(context).scale(14) * 3).clamp(
                    210,
                    270,
                  ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final file in controller.files.where(
                  (f) => !'${f['mime']}'.startsWith('audio/'),
                ))
                  SizedBox(
                    width: 150,
                    child: AppSection(
                      margin: const EdgeInsets.all(4),
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              height: 86,
                              child: Center(
                                child: '${file['mime']}'.startsWith('image/')
                                    ? Image.file(
                                        File('${file['path']}'),
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: 36,
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: AppIconButton(
                                tooltip: context.l10n.remove,
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => controller.remove(file),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${file['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (controller.location != null)
                  SizedBox(
                    width: 280,
                    child: Stack(
                      children: [
                        // ChatLocationPreview: the delivered bubble's
                        // content on the incoming fill, 12pt corners.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppPalette.of(context).incoming,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: LocationAttachment(
                            location: controller.location!,
                            width: 280,
                            radius: 12,
                            onPressed: () => pickLocation(context, controller),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: AppIconButton(
                            glass: true,
                            symbolSize: 16,
                            tooltip: context.l10n.removeLocation,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              controller.location = null;
                              controller.changed();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                if (controller.emoticon != null)
                  SizedBox(
                    width: 140,
                    child: Stack(
                      children: [
                        EmoticonView(document: controller.emoticon!, size: 120),
                        Positioned(
                          right: 0,
                          child: AppIconButton(
                            tooltip: context.l10n.remove,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              controller.emoticon = null;
                              controller.changed();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// One compact recording surface for both chat and expanded post composers.
class VoiceRecordingBar extends StatelessWidget {
  final AttachmentController controller;
  final VoidCallback? onCancel, onStop, onSend;
  final bool busy;
  const VoiceRecordingBar({
    super.key,
    required this.controller,
    this.onCancel,
    this.onStop,
    this.onSend,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final time =
        '${controller.seconds ~/ 60}:${(controller.seconds % 60).toString().padLeft(2, '0')}';
    return GlassSurface(
      role: GlassSurfaceRole.input,
      radius: 22,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            AppIconButton(
              embedded: true,
              tooltip: context.l10n.cancel,
              icon: const Icon(Icons.delete_outline, size: 22),
              color: palette.destructive,
              onPressed: busy ? null : onCancel,
            ),
            Icon(Icons.mic, size: 16, color: palette.destructive),
            const SizedBox(width: 6),
            Text(time, style: AppDesign.font(15, color: palette.text)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CustomPaint(
                  size: const Size(double.infinity, 22),
                  painter: _VoiceLevels(
                    List<double>.of(controller.amplitudes),
                    palette.accent,
                  ),
                ),
              ),
            ),
            if (onStop != null)
              AppIconButton(
                embedded: true,
                tooltip: context.l10n.stopRecording2,
                icon: const Icon(Icons.stop, size: 22),
                color: palette.destructive,
                onPressed: busy ? null : onStop,
              ),
            if (onSend != null)
              AppIconButton(
                embedded: true,
                prominent: true,
                tooltip: context.l10n.send,
                icon: const Icon(Icons.arrow_upward, size: 22),
                onPressed: busy ? null : onSend,
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceLevels extends CustomPainter {
  final List<double> values;
  final Color color;
  const _VoiceLevels(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final count = (size.width / 4).floor().clamp(0, 40);
    for (var i = 0; i < count; i++) {
      final index = values.length - count + i;
      final level = index < 0 ? 0.0 : values[index];
      final height = 2 + level * (size.height - 2);
      final x = size.width - (count - i) * 4 + 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceLevels old) =>
      old.color != color || !listEquals(old.values, values);
}
