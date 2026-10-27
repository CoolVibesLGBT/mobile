import 'dart:convert';
import 'place_search.dart';
import 'server_endpoints.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef Json = Map<String, dynamic>;
Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
Json userRecord(dynamic value) {
  final record = object(value);
  return record['user'] is Map ? object(record['user']) : record;
}

String string(dynamic value) => value == null ? '' : '$value';
String recordId(Json record) => string(
  record['public_id'] ?? record['id'] ?? record['post_id'] ?? record['chat_id'],
);

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? status;
  final bool connectionFailure;
  ApiException(this.message, [this.status, this.code])
    : connectionFailure = false;
  ApiException.connection(this.message)
    : status = null,
      code = null,
      connectionFailure = true;
  @override
  String toString() => message;
}

class Api {
  static ServerEndpoints get endpoints => ServerEndpoints.resolve(
    apiOverride: const String.fromEnvironment('API_URL'),
    socketOverride: const String.fromEnvironment('SOCKET_URL'),
    developmentHost: const String.fromEnvironment('DEV_HOST'),
    release: kReleaseMode,
    android: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  );
  static String get baseUrl => endpoints.api.toString();
  static String get socketUrl => endpoints.socket.toString();
  static String get localHost => endpoints.api.host;
  final Dio dio;
  final PlaceSearch places;
  final FlutterSecureStorage storage;
  String? token;

  /// apiService media headers: `/static/uploads` on the API host is served
  /// through media access control, which reads the viewer from a Bearer
  /// token (private chat media is 404 without it). Other hosts get none.
  Map<String, String>? mediaHeaders(String url) {
    final value = token;
    final uri = Uri.tryParse(url);
    if (value == null || value.isEmpty || uri == null) return null;
    final base = Uri.parse(baseUrl);
    if (uri.host != base.host ||
        uri.port != base.port ||
        !uri.path.startsWith('/static/uploads/')) {
      return null;
    }
    return {
      'Authorization': value.startsWith('Bearer ') ? value : 'Bearer $value',
    };
  }

  bool get isPreview => false;
  void Function(String expiredToken)? onUnauthorized;
  Future<void> _storageQueue = Future<void>.value();
  Future<T> _locked<T>(Future<T> Function() task) {
    final result = _storageQueue.then((_) => task());
    _storageQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Api({
    Dio? client,
    FlutterSecureStorage? secureStorage,
    PlaceSearch? placeSearch,
  }) : places = placeSearch ?? PlaceSearch(),
       dio =
           client ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       storage =
           secureStorage ??
           const FlutterSecureStorage(
             mOptions: MacOsOptions(usesDataProtectionKeychain: false),
           );

  Future<void> restore() => _locked(() async {
    token = await storage.read(key: 'authToken');
  });
  Future<void> saveToken(String value) => _locked(() async {
    final next = value.startsWith('Bearer ') ? value : 'Bearer $value';
    await storage.write(key: 'authToken', value: next);
    token = next;
  });
  Future<void> clearToken() => _locked(() async {
    token = null;
    await storage.delete(key: 'authToken');
  });
  Future<bool> invalidate(String expectedToken) => _locked(() async {
    if (token != expectedToken) return false;
    token = null;
    await storage.delete(key: 'authToken');
    return true;
  });

  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    final requestToken = token;
    try {
      final headers = <String, dynamic>{
        'Authorization': ?requestToken,
        'X-Action': action,
      };
      final fields = <String, dynamic>{'action': action};
      for (final entry in body.entries) {
        final value = entry.value;
        if (value == null) continue;
        fields[entry.key] =
            value is MultipartFile ||
                (value is List && entry.key.endsWith('[]'))
            ? value
            : value is Map || value is List
            ? jsonEncode(value)
            : '$value';
      }
      final response = get
          ? await dio.get<dynamic>(
              '/',
              queryParameters: fields,
              options: Options(
                headers: headers,
                receiveTimeout: receiveTimeout,
              ),
              cancelToken: cancelToken,
            )
          : await dio.post<dynamic>(
              '/',
              data: FormData.fromMap(fields, ListFormat.multi),
              options: Options(
                headers: headers,
                receiveTimeout: receiveTimeout,
              ),
              cancelToken: cancelToken,
              onSendProgress: onSendProgress,
            );
      final result = object(
        response.data is String ? jsonDecode(response.data) : response.data,
      );
      if (result['success'] == false) {
        throw ApiException(
          string(result['message'] ?? result['error'] ?? 'Request failed'),
          response.statusCode,
          result['code'] is String ? result['code'] as String : null,
        );
      }
      return result;
    } on DioException catch (error) {
      // The service also answers 401 for rejected input (INVALID_INPUT), so only
      // `auth.user_info` proves the session is gone (source apiService/auth slice).
      if (error.response?.statusCode == 401 &&
          requestToken != null &&
          action == 'auth.user_info') {
        onUnauthorized?.call(requestToken);
      }
      final data = object(error.response?.data);
      final message = string(
        data['message'] ??
            data['error'] ??
            error.message ??
            'Connection failed',
      );
      if (error.response == null) throw ApiException.connection(message);
      throw ApiException(
        message,
        error.response?.statusCode,
        data['code'] is String ? data['code'] as String : null,
      );
    }
  }
}

/// Preserve service cursors; never infer that a short page is the last page.
class RecordPage {
  final List<Json> records;
  final String? next;
  RecordPage(this.records, this.next);
  factory RecordPage.parse(Json response, {String? key}) {
    dynamic data = response['data'] ?? response;
    final container = object(data);
    dynamic rows = data is List ? data : null;
    for (final candidate in [
      ?key,
      'items',
      'posts',
      'users',
      'chats',
      'messages',
      'notifications',
      'places',
      'stories',
      'check_ins',
      'checkins',
      'results',
      'photos',
      'requests',
      'participants',
      'matches',
      'offers',
      'friendships',
      'friends',
      'followers',
      'followings',
      'engagements',
      'groups',
    ]) {
      if (container[candidate] is List) {
        rows = container[candidate];
        break;
      }
    }
    final pagination = object(
      container['pagination'] ?? response['pagination'],
    );
    dynamic cursor =
        container['next_cursor'] ??
        container['nextCursor'] ??
        pagination['next_cursor'] ??
        pagination['next'] ??
        response['next_cursor'];
    if (cursor == null) {
      final rawCursor = container['cursor'] ?? response['cursor'];
      cursor = rawCursor is Map ? object(rawCursor)['next'] : rawCursor;
    }
    return RecordPage(
      rows is List ? rows.whereType<Map>().map(object).toList() : [],
      cursor == null || '$cursor'.isEmpty ? null : '$cursor',
    );
  }
}

String plainText(dynamic value, {String? language}) {
  if (value == null) return '';
  if (value is String) {
    final trimmed = value.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return plainText(jsonDecode(value), language: language);
      } catch (_) {}
    }
    return value;
  }
  if (value is List) {
    return value
        .map((v) => plainText(v, language: language))
        .where((s) => s.isNotEmpty)
        .join('\n');
  }
  final map = object(value);
  if (map['text'] != null) return string(map['text']);
  if (map['type'] == 'linebreak') return '\n';
  if (map['root'] != null) return plainText(map['root'], language: language);
  if (map['children'] is List) {
    return (map['children'] as List)
        .map((v) => plainText(v, language: language))
        .join(map['type'] == 'root' ? '\n' : '');
  }
  final localized = map[language] ?? map['en'] ?? map['tr'] ?? map['ar'];
  if (localized != null) return plainText(localized, language: language);
  return '';
}

Json lexical(String text) => {
  'root': {
    'children': text
        .split('\n')
        .map(
          (line) => {
            'children': [
              {
                'detail': 0,
                'format': 0,
                'mode': 'normal',
                'style': '',
                'text': line,
                'type': 'text',
                'version': 1,
              },
            ],
            'direction': null,
            'format': '',
            'indent': 0,
            'type': 'paragraph',
            'version': 1,
            'textFormat': 0,
            'textStyle': '',
          },
        )
        .toList(),
    'direction': null,
    'format': '',
    'indent': 0,
    'type': 'root',
    'version': 1,
  },
};

/// Resolve API attachments and variants exactly as the previous client does.
String assetUrl(dynamic attachment, {String variant = 'original'}) {
  if (attachment == null) return '';
  if (attachment is! String) {
    final item = object(attachment);
    final file = object(item['file']);
    final variants = object(file['variants'] ?? item['variants']);
    final images = object(variants['image'] ?? variants['video']);
    dynamic path;
    for (final name in [variant, 'small', 'thumbnail', 'medium', 'original']) {
      path ??= object(images[name])['url'];
    }
    return assetUrl(path ?? file['url'] ?? item['url'] ?? item['src']);
  }
  if (attachment.isEmpty) return '';
  final uri = Uri.tryParse(attachment);
  if (uri == null) return '';
  if (uri.hasScheme) {
    return ['http', 'https'].contains(uri.scheme) ? '$uri' : '';
  }
  final clean = attachment.startsWith('./')
      ? attachment.substring(2)
      : attachment;
  return Uri.parse(
    Api.baseUrl,
  ).resolve(clean.startsWith('/') ? clean : '/$clean').toString();
}
