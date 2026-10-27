import 'package:dio/dio.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/debug/preview_api.dart';

const conversation = 'c9e36732-6171-4fcf-b786-f352ab7f7115';
const messageUuid = 'ac406ac6-1c1c-4319-8f18-6f2e78e2a1eb';

class ContractApi extends PreviewApi {
  ContractApi() : super(PreviewState.populated);
  final calls = <({String action, Json body})>[];
  bool failSend = true;
  final sent = <Json>[];
  final createdPosts = <Json>[];
  final chats = <Json>[
    {...previewChat, 'id': conversation},
  ];
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    calls.add((action: action, body: Map.of(body)));
    if (action == 'post.create') {
      final post = <String, dynamic>{
        ...previewPost,
        'id': 'fixture-post-${createdPosts.length + 1}',
        'content': body['content'],
      };
      createdPosts.add(post);
      return {
        'success': true,
        'data': {'post': post},
      };
    }
    if (action == 'chat.fetch_chats') {
      return {
        'success': true,
        'data': {'chats': chats},
      };
    }
    if (action == 'chat.delete_chat_for_user') {
      chats.removeWhere((chat) => chat['id'] == body['chat_id']);
      return {'success': true};
    }
    if (action == 'chat.set_muted') return {'success': true};
    if (action == 'chat.edit_message') {
      final message = sent.firstWhere((m) => m['id'] == body['message_id']);
      message['content'] = {'tr': body['content']};
      return {
        'success': true,
        'data': {'message': message},
      };
    }
    if (action == 'chat.delete_message_for_user' ||
        action == 'chat.delete_message_for_all') {
      sent.removeWhere((m) => m['id'] == body['message_id']);
      return {'success': true};
    }
    if (action == 'chat.forward_messages') {
      return super.call(action, body: body);
    }
    if (action == 'user.friend.fetch') {
      return {
        'success': true,
        'data': {
          'friendships': [
            {
              'request_id': 'friendship-1',
              'status': 'accepted',
              'user': previewPeer,
            },
          ],
        },
      };
    }
    if (action == 'chat.create') {
      return {
        'success': true,
        'data': {
          'chat': {...previewChat, 'id': conversation},
        },
      };
    }
    if (action == 'auth.user_info') {
      return {'success': true, 'data': previewSelf};
    }
    if (action == 'chat.fetch_messages') {
      return {
        'success': true,
        'data': {'messages': sent},
      };
    }
    if (action == 'chat.message_read') return {'success': true};
    if (action == 'chat.send_message') {
      if (failSend) throw ApiException('Test connection failure');
      final row = <String, dynamic>{
        'id': messageUuid,
        'public_id': '99999',
        'content': {'tr': body['content']},
        'chat_id': conversation,
        'author_id': previewSelf['public_id'],
        'created_at': '2026-10-24T10:00:00Z',
      };
      sent.add(row);
      return {
        'success': true,
        'data': {'message': row},
      };
    }
    return super.call(
      action,
      body: body,
      get: get,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      receiveTimeout: receiveTimeout,
    );
  }
}
