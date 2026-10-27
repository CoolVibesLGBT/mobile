import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/realtime.dart';
import 'package:coolvibes/core/server_endpoints.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Opt-in: authenticates a local test account; never posts or messages anyone.
void main() {
  const enabled = bool.fromEnvironment('RUN_LOCAL_SERVICES');
  final endpoints = ServerEndpoints.resolve(
    developmentHost: const String.fromEnvironment(
      'DEV_HOST',
      defaultValue: '127.0.0.1',
    ),
    apiOverride: const String.fromEnvironment('API_URL'),
    socketOverride: const String.fromEnvironment('SOCKET_URL'),
  );
  test(
    'local Go HTTP login authenticates Socket.IO and recovers after disconnect',
    () async {
      final api = Api(
        client: Dio(
          BaseOptions(
            baseUrl: endpoints.api.toString(),
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ),
      );
      final live = AppRealtime();
      try {
        final result = await api.call(
          'auth.login',
          body: {
            'nickname': const String.fromEnvironment(
              'LOGIN_NICKNAME',
              defaultValue: 'demo',
            ),
            'password': const String.fromEnvironment(
              'LOGIN_PASSWORD',
              defaultValue: 'demo',
            ),
          },
        );
        final token = string(object(result['data'])['token']);
        expect(token, isNotEmpty);
        final authenticated = live.events
            .firstWhere((e) => e.name == 'sync')
            .timeout(const Duration(seconds: 12));
        live.connect(url: endpoints.socket.toString(), token: token);
        await authenticated;
        expect(live.status, RealtimeStatus.online);
        final recovered = live.events
            .firstWhere((e) => e.name == 'sync')
            .timeout(const Duration(seconds: 12));
        live.socket!.disconnect();
        live.resume();
        await recovered;
        expect(live.status, RealtimeStatus.online);
      } finally {
        live.dispose();
        api.dio.close(force: true);
      }
    },
    skip: !enabled,
  );

  test('local Go rejects invalid socket authentication', () async {
    final live = AppRealtime();
    try {
      final rejected = live.events
          .firstWhere((e) => e.name == 'auth:rejected')
          .timeout(const Duration(seconds: 12));
      live.connect(
        url: endpoints.socket.toString(),
        token: 'not-a-valid-session',
      );
      await rejected;
      expect(live.status, RealtimeStatus.rejected);
    } finally {
      live.dispose();
    }
  }, skip: !enabled);
}
