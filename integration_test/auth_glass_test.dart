import 'support/native_frames.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mime/mime.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/components/app_field.dart';
import 'package:coolvibes/components/app_pressable.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/auth.dart';
import 'package:coolvibes/screens/shell.dart';
import 'package:coolvibes/components/radar_profile_card.dart';

class TransportSession extends Session {
  TransportSession(super.api) : super(persistPreferences: false);
  @override
  void connect() {} // No real socket connection for isolated HTTP fixtures.
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  testWidgets(
    'iOS login uses real multipart HTTP and Keychain; rejection can be corrected',
    (tester) async {
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final logins = <Json>[];
      server.listen((request) async {
        final fields = <String, String>{};
        final boundary = request.headers.contentType?.parameters['boundary'];
        if (boundary != null) {
          await for (final part in MimeMultipartTransformer(
            boundary,
          ).bind(request)) {
            final name = HeaderValue.parse(
              part.headers['content-disposition']!,
            ).parameters['name']!;
            fields[name] = await utf8.decoder.bind(part).join();
          }
        }
        final action =
            request.headers.value('X-Action') ??
            request.uri.queryParameters['action'];
        Json result = {'success': true, 'data': <dynamic>[]};
        if (action == 'auth.login') {
          logins.add({'path': request.uri.path, ...fields});
          if (fields['nickname'] == 'native@example.com' &&
              fields['password'] == 'Native-test-Password') {
            result = {
              'success': true,
              'data': {'token': 'integration-only-token', 'user': previewSelf},
            };
          } else {
            request.response.statusCode = 401;
            result = {
              'success': false,
              'code': 'INVALID_INPUT',
              'message': 'Invalid input provided.',
            };
          }
        } else if (action == 'auth.user_info') {
          result = {'success': true, 'data': previewSelf};
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(result));
        await request.response.close();
      });
      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(accountName: 'coolvibes.integration.auth'),
      );
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:${server.port}/api',
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final api = Api(client: dio, secureStorage: storage);
      addTearDown(() async {
        await api.clearToken();
        dio.close(force: true);
        await server.close(force: true);
      });
      await api.clearToken();
      final session = TransportSession(api)..ready = true;
      await tester.pumpWidget(CoolvibesApp(session: session));
      await pumpUI(tester);
      await pumpNativeFrames(tester);
      await nativeTap(tester, find.byKey(const ValueKey('auth.choice.login')));
      await pumpUI(tester);
      await nativeTap(tester, find.byKey(const ValueKey('auth.submit')));
      await pumpUI(tester);
      final fields = find.descendant(
        of: find.byType(AppField),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), ' Native@Example.com ');
      await tester.enterText(fields.at(1), 'wrong-test-password');
      final signIn = find.byKey(const ValueKey('auth.submit'));
      await pumpUI(tester);
      expect(logins, isEmpty, reason: 'Entering credentials must not submit');
      await nativeTap(tester, signIn);
      await pumpUI(tester);
      expect(
        logins.length,
        1,
        reason: 'One tap must produce exactly one login request',
      );
      expect(api.token, isNull);
      expect(
        find.text('Kullanıcı adını veya e-postanı ve şifreni kontrol et.'),
        findsOneWidget,
      );
      await pumpNativeFrames(tester);
      await tester.showKeyboard(fields.at(1));
      await pumpUI(tester);
      await tester.enterText(fields.at(1), 'Native-test-Password');
      await pumpUI(tester);
      expect(
        tester.widget<TextField>(fields.at(1)).controller!.text,
        'Native-test-Password',
      );
      await pumpUI(tester);
      await nativeTap(tester, signIn);
      await pumpUI(tester);
      expect(logins.length, 2);
      expect(logins.last['path'], '/api/');
      expect(logins.last['nickname'], 'native@example.com');
      expect(logins.last['password'], 'Native-test-Password');
      expect(api.token, 'Bearer integration-only-token');
      expect(find.byType(Shell), findsOneWidget);
      final restored = Api(client: dio, secureStorage: storage);
      await restored.restore();
      expect(
        restored.token,
        api.token,
        reason: 'Must actually persist to iOS Keychain',
      );
      await pumpNativeFrames(tester);
      await session.logout();
      await pumpUI(tester);
      expect(find.byType(AuthScreen), findsOneWidget);
      await restored.restore();
      expect(restored.token, isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      dio.close(force: true);
      await server.close(force: true);
    },
  );

  testWidgets(
    'radar press feedback is immediate and cancellation does not select',
    (tester) async {
      final session =
          Session(PreviewApi(PreviewState.populated), persistPreferences: false)
            ..ready = true
            ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const Shell(initialTab: 2)),
      );
      await pumpUI(tester);
      await pumpNativeFrames(tester);
      final bubbles = find.byWidgetPredicate(
        (w) => w is AppPressable && w.style == AppPressStyle.radar,
      );
      final bubble = bubbles.last;
      final pointer = await tester.startGesture(tester.getCenter(bubble));
      await tester.pump();
      final opacity = tester.widget<Opacity>(
        find.descendant(of: bubble, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, .8);
      await pumpNativeFrames(tester);
      await pointer.cancel();
      await tester.pump();
      expect(find.byType(RadarProfileCard), findsNothing);
      await tester.tap(bubble);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RadarProfileCard), findsOneWidget);
      await pumpNativeFrames(tester);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
