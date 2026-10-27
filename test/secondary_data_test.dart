import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/classified_data.dart';
import 'package:coolvibes/core/notification_data.dart';
import 'package:coolvibes/core/premium.dart';
import 'package:coolvibes/core/realtime.dart';

void main() {
  test(
    'classified translation falls back to the source language before dictionary order',
    () {
      final post = {
        'default_language': 'en',
        'title': {'fr': 'Annonce', 'en': 'Listing'},
        'extras': {
          'metadata': [
            {
              'key': {'fr': 'Ville', 'en': 'City'},
              'value': {'fr': 'Londres', 'en': 'London'},
            },
          ],
        },
      };
      expect(classifiedTitle(post, 'ar'), 'Listing');
      expect(classifiedMetadata(post, 'ar'), [
        (label: 'City', value: 'London'),
      ]);
    },
  );
  test('classified legacy extras and localized metadata remain readable', () {
    final post = {
      'public_id': '42',
      'post_kind': 'job_offer',
      'extras': jsonEncode({
        'title': {'en': 'Barista wanted'},
        'metadata': {
          'City': {'tr': 'İstanbul'},
          'Empty': '',
        },
      }),
    };
    expect(classifiedTitle(post, 'tr'), 'Barista wanted');
    expect(classifiedMetadata(post, 'tr'), [
      (label: 'City', value: 'İstanbul'),
    ]);
    expect(classifiedMatches(post, 'barista İstanbul', 'tr'), isTrue);
    expect(
      classifiedFromResponse({
        'data': {'post': post},
      }, '42'),
      post,
    );
    expect(classifiedFromResponse({'data': post}, '43'), isNull);
  });
  test(
    'notification serialized payload preserves target and localized fallback',
    () {
      final item = {
        'sender': {'public_id': 'sender'},
        'user': {'public_id': 'wrong'},
        'is_read': 1,
        'type': 'comment',
        'message': '',
        'payload': jsonEncode({
          'body': {'en': 'Commented'},
          'data': {'post_id': '42'},
        }),
      };
      expect(notificationSender(item)['public_id'], 'sender');
      expect(notificationTarget(item)['post_id'], '42');
      expect(notificationText(item, 'tr'), 'Commented');
      expect(notificationUnread(item), isFalse);
      expect(notificationCategory(item), 'reactions');
    },
  );
  test('premium entitlement avoids accidental substring matches', () {
    expect(hasPremiumAccess({'user_role': 'professional'}), isFalse);
    expect(
      hasPremiumAccess({
        'subscription': {'status': 'expired'},
      }),
      isFalse,
    );
    expect(hasPremiumAccess({'user_role': 'member,premium'}), isTrue);
    expect(
      hasPremiumAccess({
        'subscription': {'status': 'active'},
      }),
      isTrue,
    );
  });
  test('post changes invalidate both classified lists and details', () {
    const event = RealtimeEvent('post', {'action': 'post.changed'});
    for (final action in [
      'classifieds.offers',
      'classifieds.search',
      'classifieds.get',
    ]) {
      expect(event.affects(action), isTrue);
    }
    expect(event.affects('chat.fetch_messages'), isFalse);
  });
}
