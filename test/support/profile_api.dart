import 'dart:async';
import 'package:dio/dio.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'contract_api.dart';

class ProfileApi extends ContractApi {
  Json peer = {...previewPeer, 'created_at': '2024-04-10T09:00:00Z'};
  Json self = {...previewSelf, 'created_at': '2024-04-10T09:00:00Z'};
  String access = 'none';
  Completer<void>? followGate, accessGate;
  Completer<Json>? profileGate;
  ApiException? profileError, privateError, publicError;
  ApiException? updateError;
  bool paging = false;
  final publicPhotos = <Json>[
    {'public_id': '41', 'localAsset': 'assets/images/brand.png'},
  ];
  final privatePhotos = <Json>[
    {'public_id': '42', 'localAsset': 'assets/images/brand.png'},
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
    const owned = {
      'auth.user_info',
      'user.fetch_profile',
      'user.follow.toggle',
      'user.block.toggle',
      'user.fetch.posts',
      'user.fetch.posts.likes',
      'user.private_photos.fetch',
      'user.profile_photos.fetch',
      'user.private_photos.access.request',
      'user.photos.move',
      'user.private_photos.delete',
      'user.update_profile',
    };
    if (!owned.contains(action)) {
      return super.call(
        action,
        body: body,
        get: get,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        receiveTimeout: receiveTimeout,
      );
    }
    calls.add((action: action, body: Map.of(body)));
    Json data(dynamic value) => {'success': true, 'data': value};
    switch (action) {
      case 'auth.user_info':
        return data(self);
      case 'user.update_profile':
        if (updateError != null) throw updateError!;
        self.addAll(body);
        return data({'user': self});
      case 'user.fetch_profile':
        if (profileGate != null) return profileGate!.future;
        if (profileError != null) throw profileError!;
        return data({'user': Map.of(peer)});
      case 'user.follow.toggle':
        await followGate?.future;
        peer['is_following'] = peer['is_following'] != true;
        return data({'status': peer['is_following'], 'user': self});
      case 'user.block.toggle':
        return data({'status': true});
      case 'user.fetch.posts':
      case 'user.fetch.posts.likes':
        final page = body['cursor'] == 'next' ? 1 : 0;
        return data({
          'posts': [
            for (var i = 0; i < (paging ? 12 : 2); i++)
              {
                ...previewPost,
                'public_id': '${100 + page * 12 + i}',
                'id': 'post-${page * 12 + i}',
                'content': lexical('Profile post ${page * 12 + i}'),
              },
          ],
          if (paging && page == 0) 'next_cursor': 'next',
        });
      case 'user.private_photos.fetch':
        if (privateError != null) throw privateError!;
        final owner = body['owner_id'] == null;
        return data({
          'owner_id': body['owner_id'] ?? self['public_id'],
          'access': {'status': owner ? 'owner' : access},
          'count': privatePhotos.length,
          'photos': owner || access == 'approved' ? List.of(privatePhotos) : [],
        });
      case 'user.profile_photos.fetch':
        if (publicError != null) throw publicError!;
        return data({'photos': List.of(publicPhotos)});
      case 'user.private_photos.access.request':
        await accessGate?.future;
        access = 'pending';
        return data({'status': access, 'request_id': '71'});
      case 'user.photos.move':
        final toPublic = body['destination'] == 'public';
        final source = toPublic ? privatePhotos : publicPhotos;
        final target = toPublic ? publicPhotos : privatePhotos;
        final photo = source.firstWhere(
          (p) => p['public_id'] == body['photo_id'],
        );
        source.remove(photo);
        target.add(photo);
        return data({});
      case 'user.private_photos.delete':
        if (!privatePhotos.any((p) => p['public_id'] == body['photo_id'])) {
          throw ApiException('Photo not found', 404);
        }
        privatePhotos.removeWhere((p) => p['public_id'] == body['photo_id']);
        return data({});
    }
    throw StateError(action);
  }
}
