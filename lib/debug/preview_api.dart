import 'dart:convert';
import 'package:dio/dio.dart';
import 'dart:async';
import '../core/api.dart';
import '../core/place_search.dart';
import '../core/profile_preferences.dart';

// This adapter is reachable only through the debug gallery. It never delegates
// requests or mutations to the production transport.
enum PreviewState { populated, empty, loading, error }

final previewSelf = <String, dynamic>{
  'id': '1',
  'public_id': '1001',
  'localAsset': 'assets/avatars/1001.svg',
  'displayname': 'Deniz',
  'username': 'deniz',
  'nickname': 'deniz',
  'bio': 'Şehrin yeni hikâyeleri. Müzik, sanat ve güzel sohbetler.',
};
final previewPeer = <String, dynamic>{
  'id': '2',
  'public_id': '1002',
  'localAsset': 'assets/avatars/1002.svg',
  'displayname': 'Ege',
  'username': 'ege',
  'nickname': 'ege',
  'bio': 'Yeni yerler keşfetmeyi seviyorum.',
  'latitude': 41.01,
  'longitude': 28.98,
  'distance': '1.2 km',
};
final previewPost = <String, dynamic>{
  'id': 'p1',
  'public_id': '2001',
  'user': previewPeer,
  'content': lexical('Bugün İstanbul çok güzel. Akşam bir kahve içelim mi?'),
  'created_at': '2026-10-24T13:30:00Z',
  'likes_count': 24,
  'comments_count': 3,
};
final previewChat = <String, dynamic>{
  'id': 'c1',
  'public_id': '3001',
  'title': 'Ege',
  'type': 'private',
  'peer': previewPeer,
  'last_message': {'content': 'Birazdan oradayım'},
  'unread_count': 2,
};
final previewGroup = <String, dynamic>{
  ...previewChat,
  'id': 'g1',
  'public_id': '3002',
  'title': 'İstanbul buluşması',
  'type': 'group',
  'visibility': 'private',
  'description': 'Hafta sonu buluşmalarımız',
};
final previewPlace = <String, dynamic>{
  'id': 'v1',
  'public_id': '4001',
  'name': 'Moda Sahili',
  'title': 'Moda Sahili',
  'address': 'Kadıköy, İstanbul',
  'description': 'Birlikte vakit geçirmek için sevdiğimiz yer.',
  'latitude': 40.98,
  'longitude': 29.02,
};
final previewClassified = <String, dynamic>{
  ...previewPost,
  'title': 'Tasarımcı arıyoruz',
  'kind': 'job_offer',
  'extras': {'title': 'Tasarımcı arıyoruz'},
  'content': lexical('Yaratıcı ekibimize katılacak bir tasarımcı arıyoruz.'),
};

final previewSystem = <String, dynamic>{
  'checkin_tag_types': [
    {
      'tag': 'coffee',
      'name': {'tr': 'Kahve', 'en': 'Coffee'},
      'icon': 'coffee',
      'is_visible': true,
    },
    {
      'tag': 'music',
      'name': {'tr': 'Müzik', 'en': 'Music'},
      'icon': 'music',
      'is_visible': true,
    },
    {
      'tag': 'walk',
      'name': {'tr': 'Yürüyüş', 'en': 'Walk'},
      'icon': 'walk',
      'is_visible': true,
    },
  ],
  'preferences': {
    'attributes': [
      {
        'tag': 'relationship_status',
        'title': {
          'tr': 'İlişki durumu',
          'en': 'Relationship status',
          'ar': 'الحالة الاجتماعية',
        },
        'items': [
          {
            'id': 'a1',
            'bit_index': 0,
            'title': {'tr': 'Bekâr', 'en': 'Single', 'ar': 'أعزب'},
          },
          {
            'id': 'a2',
            'bit_index': 1,
            'title': {
              'tr': 'İlişkisi var',
              'en': 'In a relationship',
              'ar': 'في علاقة',
            },
          },
        ],
      },
    ],
    'interests': [
      {
        'tag': 'interests',
        'title': {'tr': 'İlgi alanları', 'en': 'Interests', 'ar': 'الاهتمامات'},
        'items': [
          {
            'id': 'i1',
            'bit_index': 2,
            'title': {'tr': 'Müzik', 'en': 'Music', 'ar': 'الموسيقى'},
          },
          {
            'id': 'i2',
            'bit_index': 3,
            'title': {'tr': 'Seyahat', 'en': 'Travel', 'ar': 'السفر'},
          },
        ],
      },
    ],
    'fantasies': [
      {
        "id": "64047b90-7cc2-5079-a95f-3563571f7fa0",
        "slug": "sexual-adventure",
        "title": {
          "ar": "مغامرة جنسية",
          "bn": "যৌন অ্যাডভেঞ্চার",
          "de": "Sexuelles Abenteuer",
          "en": "Sexual Adventure",
          "es": "Aventura Sexual",
          "fr": "Aventure sexuelle",
          "he": "הרפתקה מינית",
          "hi": "यौन साहसिक",
          "id": "Petualangan Seksual",
          "ja": "性的冒険",
          "pl": "Przygoda seksualna",
          "pt": "Aventura sexual",
          "ru": "Сексуальное приключение",
          "th": "การผจญภัยทางเพศ",
          "tr": "Cinsel Macera",
          "zh": "性冒险",
        },
        "allow_multiple": true,
        "items": [
          {
            "id": "ca7e2bb0-b633-5ca7-a199-51d3a73d4a36",
            "slug": "being-watched",
            "title": {
              "ar": "يجري مراقبتها",
              "bn": "পর্যবেক্ষণ করা হচ্ছে",
              "de": "Beobachtet werden",
              "en": "Being watched",
              "es": "siendo observado",
              "fr": "Être surveillé",
              "he": "Being watched",
              "hi": "नजर रखी जा रही है",
              "id": "Diawasi",
              "ja": "監視されている",
              "pl": "Bycie obserwowanym",
              "pt": "Sendo vigiado",
              "ru": "Наблюдение",
              "th": "ถูกจับตามอง",
              "tr": "İzlenmek",
              "zh": "Being watched",
            },
            "bit_index": 784,
          },
          {
            "id": "f4d44594-de1b-58cc-a7be-9a1cda82f6e9",
            "slug": "cuckolding",
            "title": {
              "ar": "الديوث",
              "bn": "ককলডিং",
              "de": "Hahnrei",
              "en": "Cuckolding",
              "es": "cuernos",
              "fr": "Cocu",
              "he": "תרנגול",
              "hi": "व्यभिचारी पति",
              "id": "selingkuh",
              "ja": "寝取られ",
              "pl": "Rogacz",
              "pt": "Corno",
              "ru": "рогоносец",
              "th": "เมียมีชู้",
              "tr": "boynuzlamak",
              "zh": "戴绿帽子",
            },
            "bit_index": 785,
          },
        ],
      },
    ],
  },
};

class PreviewApi extends Api {
  @override
  bool get isPreview => true;
  PreviewState state;
  final sentMessages = <Json>[];
  final scheduledMessages = <Json>[];
  final profileSelf = <String, dynamic>{...previewSelf};
  final profilePeer = <String, dynamic>{...previewPeer};
  String photoAccess = 'none';
  final photoRequests = <Json>[
    {
      'request_id': '71',
      'viewer_id': '1002',
      'viewer': previewPeer,
      'status': 'pending',
    },
  ];
  final photos = <Json>[
    {
      'public_id': '41',
      'localAsset': 'assets/images/brand.png',
      '_visibility': 'public',
    },
    {
      'public_id': '42',
      'localAsset': 'assets/images/brand.png',
      '_visibility': 'private',
    },
  ];

  /// Isolated pinned list (oldest first); starts with one fixture pin.
  final pinnedIds = <String>['m1', 'm3'];
  PreviewApi(this.state, {PlaceSearch? placeSearch})
    : super(placeSearch: placeSearch ?? _PreviewPlaces(state)) {
    token = 'debug-preview-only';
  }
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (state == PreviewState.loading) return Completer<Json>().future;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (state == PreviewState.error) {
      throw ApiException('Önizleme bağlantı hatası. Yeniden deneyebilirsin.');
    }
    if (state == PreviewState.empty) {
      return {'success': true, 'data': <dynamic>[]};
    }
    // Debug interactions stay in this isolated API instance and never hit HTTP.
    if (action == 'user.update_profile') {
      profileSelf.addAll(body);
      return {
        'success': true,
        'data': {'user': profileSelf},
      };
    }
    if (action == 'user.update_preferences') {
      final groups = preferenceGroups(previewSystem);
      final group = groups.firstWhere(
        (group) =>
            preferenceItems(group).any((item) => item['id'] == body['id']),
      );
      final item = preferenceItems(
        group,
      ).firstWhere((item) => item['id'] == body['id']);
      var flags = preferenceFlagsOf(profileSelf);
      if (body['enabled'] == true && !preferenceAllowsMultiple(group)) {
        for (final option in preferenceItems(group)) {
          flags = unsetBit(flags, (option['bit_index'] as num).toInt());
        }
      }
      final bit = (item['bit_index'] as num).toInt();
      flags = body['enabled'] == true
          ? setBit(flags, bit)
          : unsetBit(flags, bit);
      profileSelf.remove('selected_preference_bits');
      profileSelf['preferences_flags'] = serializePreferencesFlags(flags);
      return {
        'success': true,
        'data': {'user': Map.of(profileSelf)},
      };
    }
    if (action == 'user.follow.toggle' || action == 'user.block.toggle') {
      final flag = action == 'user.follow.toggle'
          ? 'is_following'
          : 'is_blocked';
      profilePeer[flag] = profilePeer[flag] != true;
      return {
        'success': true,
        'data': {'status': profilePeer[flag], 'user': profileSelf},
      };
    }
    if (action == 'user.private_photos.fetch' ||
        action == 'user.profile_photos.fetch') {
      final own = body['owner_id'] == null;
      final public = action == 'user.profile_photos.fetch';
      return {
        'success': true,
        'data': {
          'access': {'status': own ? 'owner' : photoAccess},
          'photos': [
            for (final photo in photos)
              if (photo['_visibility'] == (public ? 'public' : 'private') &&
                  (public || own || photoAccess == 'approved'))
                Map.of(photo),
          ],
        },
      };
    }
    if (action == 'user.private_photos.access.request') {
      photoAccess = 'pending';
      return {
        'success': true,
        'data': {
          'access': {'status': photoAccess, 'request_id': '72'},
        },
      };
    }
    if (action == 'user.private_photos.access.requests') {
      return {
        'success': true,
        'data': {
          'requests': [for (final item in photoRequests) Map.of(item)],
        },
      };
    }
    if (action == 'user.private_photos.access.respond' ||
        action == 'user.private_photos.access.revoke') {
      final item = photoRequests.firstWhere(
        (r) => action.endsWith('revoke')
            ? r['viewer_id'] == body['viewer_id']
            : r['request_id'] == body['request_id'],
      );
      item['status'] = body['decision'] ?? 'denied';
      return {
        'success': true,
        'data': {
          'access': {'status': item['status']},
        },
      };
    }
    if (action == 'user.photos.move' ||
        action == 'user.private_photos.delete') {
      final item = photos.firstWhere((p) => p['public_id'] == body['photo_id']);
      if (action == 'user.photos.move') {
        item['_visibility'] = body['destination'];
      } else {
        photos.remove(item);
      }
      return {'success': true};
    }
    if (action == 'chat.send_message') {
      final row = <String, dynamic>{
        'id': 'preview-${sentMessages.length + 1}',
        'chat_id': body['chat_id'],
        'author_id': previewSelf['public_id'],
        'content': {'tr': body['content']},
        'client_id': body['client_id'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
        if (body['reply_to'] != null) 'parent_id': body['reply_to'],
        if (body['location[lat]'] != null)
          'location': {
            'latitude': body['location[lat]'],
            'longitude': body['location[lng]'],
            'address': body['location[address]'],
          },
        // The service stores extras as a JSON string (posts.extras).
        if (body['extras'] is Map) 'extras': jsonEncode(body['extras']),
        if (body['expires_in_seconds'] != null) ...{
          'expires_in_seconds': int.tryParse('${body['expires_in_seconds']}'),
          'is_disappearing': true,
        },
        if (body['scheduled_at'] != null) 'scheduled_at': body['scheduled_at'],
      };
      (body['scheduled_at'] != null ? scheduledMessages : sentMessages).add(
        row,
      );
      return {
        'success': true,
        'data': {'message': row},
      };
    }
    if (action == 'chat.pin_message' || action == 'chat.unpin_message') {
      final id = string(body['message_id']);
      pinnedIds.remove(id);
      if (action == 'chat.pin_message') pinnedIds.add(id);
      return {'success': true};
    }
    if (action == 'chat.fetch_scheduled_messages') {
      return {
        'success': true,
        'data': {
          'messages': scheduledMessages
              .where((m) => m['chat_id'] == body['chat_id'])
              .toList(),
        },
      };
    }
    if (action == 'chat.send_scheduled_now') {
      final row = scheduledMessages
          .where((m) => m['id'] == body['message_id'])
          .firstOrNull;
      if (row != null) {
        scheduledMessages.remove(row);
        sentMessages.add({
          ...row,
          'scheduled_at': null,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      return {'success': true};
    }
    if (action == 'chat.message.open') {
      final expires = DateTime.now().add(const Duration(seconds: 60));
      return {
        'success': true,
        'data': {
          'message': {
            'id': body['message_id'],
            'content': {'tr': 'Kendini imha eden önizleme mesajı'},
            'content_hidden': false,
            'expires_at': expires.toUtc().toIso8601String(),
          },
        },
      };
    }
    if (action == 'chat.forward_messages') {
      final ids = (body['message_ids[]'] as List? ?? []).map(string).toList();
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = <Json>[
        if (string(body['content']).isNotEmpty)
          {
            'id': 'preview-${sentMessages.length + 1}',
            'chat_id': body['chat_id'],
            'author_id': previewSelf['public_id'],
            'content': {'tr': body['content']},
            'created_at': now,
          },
        for (final id in ids)
          {
            'id': 'preview-${sentMessages.length + 2}-$id',
            'chat_id': body['chat_id'],
            'author_id': previewSelf['public_id'],
            'content': {'tr': 'İletilen önizleme mesajı'},
            'extras': jsonEncode({
              'forwarded_from': {
                'name': previewPeer['displayname'],
                'date': now,
              },
            }),
            'created_at': now,
          },
      ];
      sentMessages.addAll(rows);
      return {
        'success': true,
        'data': {'messages': rows},
      };
    }
    if (action == 'chat.create') {
      return {
        'success': true,
        'data': {'chat': previewChat},
      };
    }
    final peers = [
      previewPeer,
      {
        ...previewPeer,
        'id': '3',
        'public_id': '1003',
        'localAsset': 'assets/avatars/1003.svg',
        'displayname': 'Ada',
        'username': 'ada',
        'distance': '2.4 km',
      },
    ];
    final rows = <String, List<Json>>{
      'post.timeline': [
        previewPost,
        {
          ...previewPost,
          'public_id': '2002',
          'user': previewSelf,
          'content': lexical('Yeni bir başlangıç. Coolvibes’a merhaba!'),
        },
      ],
      'post.vibes': [previewPost],
      'user.fetch.stories': [
        {
          'id': 's1',
          'user': previewPeer,
          'media': [
            {'localAsset': 'assets/images/brand.png'},
          ],
        },
      ],
      'user.fetch.posts': [previewPost],
      'user.fetch.nearby.users': [
        for (var i = 0; i < 37; i++)
          {
            ...peers[i % peers.length],
            'id': '${i + 2}',
            'public_id': '${1002 + i}',
            'location': {
              'latitude': 41.0082 + (i % 7 - 3) * .003,
              'longitude': 28.9784 + (i ~/ 7 - 2) * .003,
            },
            'localAsset': 'assets/avatars/${1001 + i % 3}.svg',
          },
      ],
      'match.fetch.matched': peers,
      'match.fetch.liked': peers,
      'match.fetch.passed': peers,
      'user.check_in_fetch': [previewPost],
      'chat.fetch_chats': [previewChat, previewGroup],
      'chat.fetch_messages': [
        ...sentMessages.where((m) => m['chat_id'] == body['chat_id']),
        {
          'id': 'm7',
          'author_id': '2',
          'content': '',
          'content_hidden': true,
          'is_disappearing': true,
          'expires_in_seconds': 60,
          'created_at': '2026-10-24T13:36:00Z',
        },
        {
          'id': 'm6',
          'author_id': '2',
          'content': '',
          'attachments': [
            {
              'localAsset': 'assets/images/brand.png',
              'file': {'mime_type': 'image/png'},
            },
          ],
          'extras': jsonEncode({'spoiler': true}),
          'created_at': '2026-10-24T13:35:00Z',
        },
        {
          'id': 'm5',
          'author_id': '2',
          'content': '',
          'extras': jsonEncode({
            'emoticon': {
              'kind': 'sticker',
              'id': '8cc5a62e6fc333e1',
              'url': '/animations/telegram/packs/8cc5a62e6fc333e1.tgs',
              'emoji': '😂',
              'width': 512,
              'height': 512,
            },
          }),
          'created_at': '2026-10-24T13:34:00Z',
        },
        {
          'id': 'm4',
          'author_id': '1',
          'content': 'Bu mekânı mutlaka görmelisin',
          'extras': jsonEncode({
            'forwarded_from': {'name': 'Ada', 'date': '2026-10-23T10:00:00Z'},
          }),
          'created_at': '2026-10-24T13:33:00Z',
        },
        {
          'id': 'm3',
          'author_id': '1',
          'content': 'Harika, görüşürüz!',
          'created_at': '2026-10-24T13:32:00Z',
        },
        {
          'id': 'm2',
          'author_id': '2',
          'content': 'Birazdan oradayım',
          'created_at': '2026-10-24T13:31:00Z',
        },
        {
          'id': 'm1',
          'author_id': '1',
          'content': 'Merhaba! Bugün buluşalım mı?',
          'created_at': '2026-10-24T13:30:00Z',
        },
      ],
      'chat.participants.fetch': [previewSelf, ...peers],
      'user.friend.fetch': peers,
      'search.user.lookup': peers,
      'search.trends': peers,
      'place.fetch.comments': [
        {'id': 'comment1', 'user': previewPeer, 'content': 'Harika bir yer.'},
      ],
      'classifieds.offers': [previewClassified],
      'classifieds.search': [
        {
          ...previewClassified,
          'kind': 'job_search',
          'title': 'Yeni bir fırsat arıyorum',
        },
      ],
      'user.fetch.notifications': [
        {
          'id': 'n1',
          'sender': previewPeer,
          'type': 'like',
          'message': 'Gönderini beğendi.',
          'payload': {
            'data': {'post_id': recordId(previewPost)},
          },
          'is_read': false,
          'created_at': DateTime.now()
              .subtract(const Duration(minutes: 3))
              .toIso8601String(),
        },
        {
          'id': 'n2',
          'sender': previewPeer,
          'type': 'follow',
          'message': 'Seni takip etmeye başladı.',
          'is_read': true,
          'created_at': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        },
      ],
    };
    if (rows.containsKey(action)) {
      final items = rows[action]!;
      return {
        'success': true,
        'data': {
          'items': items,
          if (action == 'chat.fetch_messages')
            'pinned_messages': [
              for (final id in pinnedIds) ...items.where((m) => m['id'] == id),
            ],
        },
      };
    }
    if (action == 'auth.user_info') {
      return {
        'success': true,
        'data': {'user': profileSelf},
      };
    }
    if (action == 'user.fetch_profile') {
      return {
        'success': true,
        'data': {'user': profilePeer},
      };
    }
    if (action == 'post.fetch' &&
        string(body['post_id']) == recordId(previewPlace)) {
      return {
        'success': true,
        'data': {
          ...previewPlace,
          'post_kind': 'place',
          'content': {
            'en': lexical('A welcoming place by the sea.'),
            'tr': lexical('Deniz kenarında bir buluşma noktası.'),
          },
          'children': <Json>[],
        },
      };
    }
    if (action == 'post.fetch') {
      return {
        'success': true,
        'data': {
          'post': previewPost,
          'replies': [
            {
              ...previewPost,
              'id': 'reply1',
              'public_id': '2003',
              'content': lexical('Harika bir fikir!'),
            },
          ],
        },
      };
    }
    if (action == 'classifieds.get') {
      return {
        'success': true,
        'data': {'post': previewClassified},
      };
    }
    if (action == 'place.fetch') {
      return {
        'success': true,
        'data': {
          'places': [previewPlace],
          'cursor': {'next': null},
        },
      };
    }
    if (action == 'system.payment_methods' || action == 'system.initial_sync') {
      return {'success': true, 'data': {}};
    }
    throw ApiException('Debug önizlemede değişiklik kaydedilmez: $action');
  }

  @override
  Future<void> restore() async {}
  @override
  Future<void> clearToken() async {
    token = null;
  }
}

class _PreviewPlaces extends PlaceSearch {
  final PreviewState state;
  _PreviewPlaces(this.state);
  @override
  Future<PlacePage> fetch({
    required double latitude,
    required double longitude,
    String query = '',
    String language = 'en',
    String? page,
    CancelToken? cancelToken,
  }) async {
    if (state == PreviewState.loading) return Completer<PlacePage>().future;
    if (state == PreviewState.error) {
      throw ApiException('Önizleme bağlantı hatası');
    }
    if (state == PreviewState.empty) return const PlacePage([]);
    return PlacePage([
      {
        'id': 'fixture-venue',
        'name': 'Moda Sahili',
        'address': 'Kadıköy, İstanbul',
        'latitude': 40.98,
        'longitude': 29.02,
        'kind': 'place',
        'delta': .02,
      },
    ]);
  }
}
