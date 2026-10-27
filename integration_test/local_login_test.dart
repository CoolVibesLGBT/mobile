import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/constants.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/screens/auth.dart';
import 'package:coolvibes/screens/captcha.dart';
import 'package:coolvibes/screens/shell.dart';
import 'support/native_frames.dart';

// Opt-in: create and delete only a new temporary account on the local Go server.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  testWidgets(
    'local registration without CAPTCHA, logout and login reach the real shell',
    (tester) async {
      expect(Api.baseUrl, 'http://localhost:4001/api');
      expect(AppConstants.registrationCaptchaEnabled, isFalse);
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final production = Api();
      final probeKey =
          'coolvibes.integration.probe.${DateTime.now().microsecondsSinceEpoch}';
      try {
        await production.storage.write(key: probeKey, value: 'keychain-probe');
        expect(await production.storage.read(key: probeKey), 'keychain-probe');
      } finally {
        await production.storage.delete(key: probeKey);
        production.dio.close(force: true);
      }
      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(accountName: 'coolvibes.integration.local-auth'),
      );
      final api = Api(secureStorage: storage);
      await api.clearToken();
      final session = Session(api, persistPreferences: false)..ready = true;
      final nickname = 'cv_auth_${DateTime.now().millisecondsSinceEpoch}';
      final password = 'Local_auth_${DateTime.now().microsecondsSinceEpoch}';
      var attemptedRegistration = false;
      Future<void> tap(Finder target) async {
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            150,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('auth.scroll')),
              matching: find.byType(Scrollable),
            ),
          );
        }
        await tester.ensureVisible(target);
        await pumpUI(tester);
        await tapUI(tester, target);
        await pumpUI(tester);
      }

      Finder input(String name) => find.descendant(
        of: find.byKey(ValueKey('auth.$name')),
        matching: find.byType(TextField),
      );
      Future<void> enter(String name, String value) async {
        final target = input(name);
        await tester.ensureVisible(target);
        await tester.showKeyboard(target);
        await pumpUI(tester);
        await tester.enterText(target, value);
        await pumpUI(tester);
      }

      Future<void> signedIn() async {
        for (var i = 0; i < 50 && find.byType(Shell).evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await pumpNativeFrames(tester);
        }
        expect(find.byType(Shell), findsOneWidget);
        expect(session.user['username'], nickname);
        final restored = Api(secureStorage: storage);
        await restored.restore();
        expect(restored.token, api.token);
        expect(api.token, startsWith('Bearer '));
        restored.dio.close(force: true);
      }

      try {
        await tester.pumpWidget(CoolvibesApp(session: session));
        await pumpUI(tester);
        await pumpNativeFrames(tester);
        await tap(find.byKey(const ValueKey('auth.choice.register')));
        expect(
          tester
              .widget<AppPressable>(
                find.byKey(const ValueKey('auth.choice.register')),
              )
              .selected,
          isTrue,
        );
        await tap(find.byKey(const ValueKey('auth.submit')));
        await enter('nickname', nickname);
        await enter('password', password);
        await enter('confirmation', password);
        await tap(find.byType(AppChoiceRow));
        debugPrint('Temporary local auth account: $nickname');
        attemptedRegistration = true;
        await tap(find.byKey(const ValueKey('auth.submit')));
        expect(find.byType(CaptchaScreen), findsNothing);
        await signedIn();
        await session.logout();
        await pumpUI(tester);
        expect(find.byType(AuthScreen), findsOneWidget);
        await tap(find.byKey(const ValueKey('auth.choice.login')));
        await tap(find.byKey(const ValueKey('auth.submit')));
        await enter('nickname', nickname);
        await enter('password', password);
        await tap(find.byKey(const ValueKey('auth.submit')));
        await signedIn();
      } finally {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        try {
          if (attemptedRegistration) {
            Json? result;
            try {
              result = await api.call(
                'auth.login',
                body: {'nickname': nickname, 'password': password},
              );
            } on ApiException catch (e) {
              if (e.status != 401) rethrow;
            }
            if (result != null) {
              final data = object(result['data']);
              expect(object(data['user'])['username'], nickname);
              await api.saveToken(string(data['token']));
              await api.call('user.delete_profile');
              debugPrint('Temporary local auth account removed.');
            }
          }
        } finally {
          await api.clearToken();
          api.dio.close(force: true);
        }
      }
    },
    skip: !const bool.fromEnvironment('RUN_LOCAL_AUTH_MUTATIONS'),
  );
}
