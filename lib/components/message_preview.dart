import 'package:flutter/widgets.dart';
import '../core/api.dart';
import '../core/chat_data.dart';
import '../core/geo.dart';
import '../l10n/l10n.dart';
import '../screens/media.dart';
import 'emoticon_view.dart';

/// Telegram MessageContentKind: one privacy-aware summary for lists and replies.
String messagePreview(BuildContext context, Json message) {
  if (message.isEmpty) return '';
  final l = context.l10n;
  bool flag(String key) => [true, 1, '1', 'true'].contains(message[key]);
  if (flag('view_once')) return l.chatViewOncePhoto;
  if (flag('content_hidden')) return l.chatHiddenMessage;
  final location = coordinatesOf(object(message['location']));
  final text = locationMessageText(
    messageContentText(
      message,
      language: Localizations.localeOf(context).languageCode,
    ),
    location,
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isNotEmpty) return text;
  final emoticon = messageEmoticon(message);
  if (emoticon != null) return emoticonLabel(context, emoticon);
  if (location != null) return l.location;
  final media = mediaOf(message);
  if (media.isNotEmpty) {
    String kind(Json item) {
      final mime = mediaMime(item),
          path = Uri.tryParse(mediaUrl(item))?.path.toLowerCase() ?? '';
      if (mime == 'image/gif' || path.endsWith('.gif')) return 'gif';
      if (audioMedia(item)) return 'audio';
      if (mime.startsWith('image/') ||
          RegExp(r'\.(jpe?g|png|webp|heic|avif)$').hasMatch(path)) {
        return 'photo';
      }
      if (mime.startsWith('video/') ||
          RegExp(r'\.(mp4|mov|webm|m4v)$').hasMatch(path)) {
        return 'video';
      }
      return 'file';
    }

    final kinds = media.map(kind).toSet();
    if (kinds.length > 1) return l.media;
    return switch (kinds.single) {
      'gif' => 'GIF',
      'audio' => l.voiceMessage,
      'photo' => media.length > 1 ? l.photos : l.photo,
      'video' => l.video,
      _ =>
        string(
              object(media.first['file'])['name'] ?? media.first['name'],
            ).trim().isNotEmpty
            ? string(object(media.first['file'])['name'] ?? media.first['name'])
            : l.file,
    };
  }
  return l.message;
}
