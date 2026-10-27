import 'package:dio/dio.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/place_search.dart';
import 'package:coolvibes/debug/preview_api.dart';

class FlowApi extends PreviewApi {
  final calls = <Json>[];
  final comments = <Json>[];
  bool reject = false;
  FlowApi({PlaceSearch? places})
    : super(PreviewState.populated, placeSearch: places);
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    calls.add({
      'action': action,
      'body': {...body},
    });
    if (['post.create', 'user.check_in'].contains(action)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (reject) throw ApiException('Gönderilemedi');
      final post = {
        'public_id': '${comments.length + 9100}',
        'author': previewSelf,
        'content': body['content'],
        'created_at': '2026-10-24T12:00:00Z',
      };
      comments.add(post);
      return {
        'success': true,
        'data': {'post': post},
      };
    }
    if (action == 'post.fetch') {
      return {
        'success': true,
        'data': {...previewPost, 'children': comments},
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
