import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/app_failure.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/app_lottie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ui_driver.dart';

void main() {
  test(
    'HTTP and authentication errors are classified without exposing payloads',
    () {
      final cases = [
        (
          ApiException.connection('https://private.example?password=secret'),
          FailureKind.connection,
        ),
        (ApiException('secret upstream body', 503), FailureKind.server),
        (
          ApiException('invalid input', 401, 'INVALID_INPUT'),
          FailureKind.credentials,
        ),
        (
          ApiException('username already exists', 401, 'USER_EXISTS'),
          FailureKind.usernameTaken,
        ),
        (ApiException('invalid referral code', 400), FailureKind.referral),
        (ApiException('invalid captcha', 401), FailureKind.captcha),
        (ApiException('secret upstream body', 429), FailureKind.rateLimited),
        (ApiException('secret upstream body', 403), FailureKind.forbidden),
        (ApiException('secret upstream body', 404), FailureKind.notFound),
        (StateError('private local path'), FailureKind.unknown),
        (PlatformException(code: 'camera_access_denied'), FailureKind.unknown),
      ];
      for (final (error, kind) in cases) {
        final failure = AppFailure.from(error, action: 'auth.login');
        expect(failure.kind, kind);
        expect(failure.diagnostic, isNot(contains('secret')));
        expect(failure.diagnostic, isNot(contains('private')));
      }
      final error = AppFailure.from(
        AuthenticationCompletionException(
          PlatformException(code: '-34018'),
          accountCreated: true,
        ),
      );
      expect(error.accountCreated, isTrue);
      expect(error.kind, FailureKind.storage);
      expect(error.diagnostic, contains('-34018'));
    },
  );

  for (final language in ['tr', 'ar']) {
    testWidgets(
      'error details stay scrollable with large text, $language and reduced motion',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        final session =
            Session(
                PreviewApi(PreviewState.populated),
                persistPreferences: false,
              )
              ..ready = true
              ..locale = Locale(language)
              ..themeMode = ThemeMode.dark;
        await tester.pumpWidget(
          CoolvibesApp(
            session: session,
            home: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showErrorSheet(
                    context,
                    const AppFailure(
                      FailureKind.server,
                      httpStatus: 503,
                      code: 'DATABASE_ERROR',
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          session.dispose();
        });
        await tester.tap(find.text('open'));
        await pumpUI(tester);
        final animation = tester.widget<AppLottie>(find.byType(AppLottie));
        expect(animation.asset, 'assets/animations/restricted.json');
        expect(animation.staticProgress, .5);
        final details = find.byType(AppRow);
        await tester.ensureVisible(details);
        await pumpUI(tester);
        await tester.tap(details);
        await pumpUI(tester);
        expect(find.text('HTTP 503 · DATABASE_ERROR'), findsOneWidget);
        final close = find.byKey(const ValueKey('error.sheet.close'));
        expect(tester.getRect(close).top, greaterThanOrEqualTo(0));
        await tester.tap(close);
        await pumpUI(tester);
        expect(find.byType(AppErrorSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
