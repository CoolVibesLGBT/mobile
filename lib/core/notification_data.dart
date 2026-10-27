import 'api.dart';
import 'localized_content.dart';

Json notificationSender(Json item) => object(
  item['sender'] ?? item['user'] ?? item['actor'] ?? item['requester'],
);
Json notificationPayload(Json item) => object(decodeContent(item['payload']));
Json notificationTarget(Json item) =>
    object(decodeContent(notificationPayload(item)['data']));
bool notificationUnread(Json item) =>
    item['is_read'] != true &&
    item['is_read'] != 1 &&
    item['is_read'] != 'true';
String notificationText(Json item, String language) =>
    [
          item['message'],
          notificationPayload(item)['body'],
          item['title'],
          notificationPayload(item)['title'],
        ]
        .map((value) => localizedText(value, language: language))
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
String notificationCategory(Json item) => switch (string(item['type'])) {
  'chat_message' || 'message_read' || 'chat_group_added' => 'messages',
  'new_match' || 'match_unmatch' => 'matches',
  'like' ||
  'unlike' ||
  'dislike' ||
  'undislike' ||
  'super_like' ||
  'banana' ||
  'banana_removed' ||
  'comment' ||
  'bookmark' ||
  'unbookmark' => 'reactions',
  'follow' ||
  'unfollow' ||
  'profile_visit' ||
  'referral' ||
  'friend_request' ||
  'friend_request_accepted' => 'people',
  'gift' || 'broadcast_gift' => 'gifts',
  _ => 'other',
};
