import 'dart:convert';
import 'api.dart';

// Chat/message commands require persistence UUIDs; public_id identifies users/posts.
String chatEntityId(Json value) => string(
  value['id'] ?? value['chat_id'] ?? value['message_id'] ?? value['public_id'],
);
Set<String> userIdentities(Json value) => [
  value['id'],
  value['public_id'],
  value['user_id'],
].map(string).where((s) => s.isNotEmpty).toSet();
bool messageIsMine(Json message, Json self) {
  final sender = {
    ...userIdentities(object(message['author'] ?? message['sender'])),
    ...[
      message['author_id'],
      message['sender_id'],
      message['user_id'],
    ].map(string).where((s) => s.isNotEmpty),
  };
  return sender.intersection(userIdentities(self)).isNotEmpty;
}

Json chatPeer(Json chat, Json self) {
  final direct = object(chat['peer'] ?? chat['user'] ?? chat['participant']);
  if (direct.isNotEmpty) return direct;
  for (final raw in chat['participants'] as List? ?? []) {
    final p = object(raw);
    final user = object(p['user'] ?? p);
    if (userIdentities(user).intersection(userIdentities(self)).isEmpty) {
      return user;
    }
  }
  return {};
}

/// normalizeChat(): groups use their own title, private chats the
/// counterpart's name before the service's generic title.
String chatTitle(Json chat, Json self, {String language = 'tr'}) {
  final title = plainText(chat['title'], language: language).trim();
  if (chat['type'] == 'group' && title.isNotEmpty) return title;
  final user = chatPeer(chat, self);
  final name = [
    user['displayname'],
    user['display_name'],
    user['username'],
  ].map(string).firstWhere((v) => v.isNotEmpty, orElse: () => '');
  return name.isNotEmpty
      ? name
      : title.isNotEmpty
      ? title
      : string(chat['name']);
}

Json socketPayload(dynamic raw) {
  if (raw is String) {
    try {
      return socketPayload(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }
  if (raw is List) return raw.isEmpty ? {} : socketPayload(raw.last);
  return object(raw);
}

Future<Json> createConversation(
  Api api,
  List<String> participants, {
  String? title,
}) async {
  final ids = participants.where((id) => id.isNotEmpty).toSet().toList();
  if (ids.isEmpty) throw ApiException('Choose a participant');
  final result = await api.call(
    'chat.create',
    body: {
      'type': ids.length > 1 ? 'group' : 'private',
      'participant_ids[]': ids,
      if (ids.length > 1 && title != null) 'title': title,
    },
  );
  final data = object(result['data']);
  final chat = object(data['chat'] ?? result['chat'] ?? data);
  if (chatEntityId(chat).isEmpty) {
    throw ApiException('Invalid conversation response');
  }
  return chat;
}

/// Message `extras` as stored by the service (JSON string or object).
Json messageExtras(Json message) {
  final raw = message['extras'];
  if (raw is String && raw.isNotEmpty) {
    try {
      return object(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }
  return object(raw);
}

/// helpers/emoticons messageEmoticon(): `emoticon ?? extras.emoticon`, only
/// when it names a sticker/GIF document and the content is not hidden.
Json? messageEmoticon(Json? message) {
  if (message == null) return null;
  if ([true, 1, '1', 'true'].contains(message['content_hidden'])) return null;
  final value = object(
    message['emoticon'] ?? messageExtras(message)['emoticon'],
  );
  if (string(value['url']).isEmpty && string(value['emoji']).isEmpty) {
    return null;
  }
  return value;
}

/// `extras.forwarded_from` written by chat.forward_messages.
Json? messageForwardOrigin(Json message) {
  final origin = object(messageExtras(message)['forwarded_from']);
  return string(origin['name']).isEmpty ? null : origin;
}

/// Author display name of a message row.
String messageAuthorName(Json message) {
  final author = object(
    message['author'] ?? message['user'] ?? message['sender'],
  );
  return string(author['displayname'] ?? author['name'] ?? author['username']);
}

String messageContentText(Json message, {String? language}) {
  for (final value in [message['content'], message['text']]) {
    final direct = plainText(value, language: language);
    if (direct.trim().isNotEmpty) return direct;
    var translations = object(value);
    if (value is String) {
      try {
        translations = object(jsonDecode(value));
      } catch (_) {}
    }
    if (translations.keys.any(['root', 'type', 'children'].contains)) continue;
    for (final localized in translations.values) {
      final text = plainText(localized, language: language);
      if (text.trim().isNotEmpty) return text;
    }
  }
  return '';
}

Json chatLastMessage(Json chat) {
  final raw = chat['last_message'];
  if (raw is Map) return object(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = object(jsonDecode(raw));
      if (decoded.containsKey('content') ||
          decoded.containsKey('attachments')) {
        return decoded;
      }
    } catch (_) {}
    return {'content': raw};
  }
  final text = chat['last_message_text'] ?? chat['message'];
  return text == null ? {} : {'content': text};
}
