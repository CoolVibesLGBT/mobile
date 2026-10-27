import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/brand_mark.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/constants.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/auth.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'support/ui_driver.dart';

class AuthApi extends PreviewApi {
  AuthApi() : super(PreviewState.populated) {
    token = null;
  }
  final logins = <Json>[];
  final registrations = <Json>[];
  Completer<void>? gate;
  Object? failure;
  Object? storageFailure;
  @override
  Future<void> saveToken(String value) async {
    if (storageFailure != null) throw storageFailure!;
    token = 'Bearer $value';
  }

  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (action == 'auth.login' || action == 'auth.register') {
      (action == 'auth.login' ? logins : registrations).add(Map.of(body));
      await gate?.future;
      if (failure != null) throw failure!;
      return {
        'data': {'token': 'fixture-auth', 'user': previewSelf},
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

Future<Session> mount(
  WidgetTester tester, {
  double width = 390,
  String language = 'tr',
  bool dark = false,
  double scale = 1,
  AuthApi? api,
}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  addTearDown(tester.view.reset);
  final session = Session(api ?? AuthApi(), persistPreferences: false)
    ..ready = true
    ..locale = Locale(language)
    ..themeMode = dark ? ThemeMode.dark : ThemeMode.light;
  await tester.pumpWidget(
    CoolvibesApp(
      session: session,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: const AuthScreen(),
        ),
      ),
    ),
  );
  await pumpUI(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await pumpUI(tester);
    session.dispose();
  });
  return session;
}

Finder field(String name) => find.descendant(
  of: find.byKey(ValueKey('auth.$name')),
  matching: find.byType(TextField),
);
Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('auth.scroll')),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await tester.ensureVisible(finder);
  await pumpUI(tester);
  await tester.tap(finder);
  await pumpUI(tester);
}

Future<void> choose(WidgetTester tester, String mode) async {
  await tap(tester, find.byKey(ValueKey('auth.choice.$mode')));
  await tap(tester, find.byKey(const ValueKey('auth.submit')));
}

void main() {
  for (final variant in [
    (320.0, 'tr', false, 1.0),
    (390.0, 'en', true, 1.0),
    (320.0, 'ar', true, 2.0),
    (820.0, 'tr', false, 1.3),
  ]) {
    final (width, language, dark, scale) = variant;
    testWidgets(
      'web choices, form geometry and keyboard reachability: $variant',
      (tester) async {
        await mount(
          tester,
          width: width,
          language: language,
          dark: dark,
          scale: scale,
        );
        final submit = find.byKey(const ValueKey('auth.submit'));
        expect(find.byType(BrandMark), findsOneWidget);
        expect(tester.widget<AppButton>(submit).onPressed, isNull);
        final buttonText = find
            .descendant(of: submit, matching: find.byType(Text))
            .first;
        expect(
          tester
              .getRect(submit)
              .inflate(.1)
              .contains(tester.getRect(buttonText).bottomRight),
          isTrue,
        );
        expect(find.byType(TextField), findsNothing);
        if (find
            .byKey(const ValueKey('auth.choice.login'))
            .evaluate()
            .isEmpty) {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('auth.choice.login')),
            250,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('auth.scroll')),
              matching: find.byType(Scrollable),
            ),
          );
        }
        expect(find.byKey(const ValueKey('auth.choice.login')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('auth.choice.register')),
          findsOneWidget,
        );
        await choose(tester, 'login');
        final l = tester.element(find.byType(AuthScreen)).l10n;
        expect(find.text(l.authLoginSubtitle), findsOneWidget);
        if (field('nickname').evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            field('nickname'),
            150,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('auth.scroll')),
              matching: find.byType(Scrollable),
            ),
          );
          await pumpUI(tester);
        }
        expect(find.byType(AppField), findsNWidgets(2));
        final nickname = tester.widget<TextField>(field('nickname'));
        expect(nickname.decoration!.enabledBorder, isA<OutlineInputBorder>());
        expect(nickname.autofillHints, contains(AutofillHints.username));
        expect(tester.widget<TextField>(field('password')).obscureText, isTrue);
        await tester.enterText(field('nickname'), 'Sample');
        await tester.enterText(field('password'), 'Secret password');
        await pumpUI(tester);
        expect(tester.widget<AppButton>(submit).onPressed, isNotNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 900);
        await pumpUI(tester);
        expect(tester.getRect(submit).bottom, lessThanOrEqualTo(544));
        await tap(tester, find.byKey(const ValueKey('auth.back')));
        tester.view.viewInsets = FakeViewPadding.zero;
        await pumpUI(tester);
        await choose(tester, 'login');
        if (field('nickname').evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            field('nickname'),
            150,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('auth.scroll')),
              matching: find.byType(Scrollable),
            ),
          );
          await pumpUI(tester);
        }
        expect(
          tester.widget<TextField>(field('nickname')).controller!.text,
          'sample',
        );
        expect(
          tester.widget<TextField>(field('password')).controller!.text,
          'Secret password',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'login submits once, preserves credentials after failure and saves the authenticated session',
    (tester) async {
      final api = AuthApi()
        ..failure = ApiException.connection('Fixture offline')
        ..gate = Completer<void>();
      final session = await mount(tester, api: api);
      await choose(tester, 'login');
      await tester.enterText(field('nickname'), ' User@Example.com ');
      await tester.enterText(field('password'), ' Secret ');
      await pumpUI(tester);
      final submit = find.byKey(const ValueKey('auth.submit'));
      await tap(tester, submit);
      expect(api.logins.length, 1);
      expect(tester.widget<AppButton>(submit).loading, isTrue);
      await tester.tap(submit);
      await pumpUI(tester);
      expect(api.logins.length, 1);
      api.gate!.complete();
      await pumpUI(tester);
      final l = tester.element(find.byType(AuthScreen)).l10n;
      expect(find.text(l.unableToReachTheServiceCheck), findsOneWidget);
      expect(api.token, isNull);
      expect(
        tester.widget<TextField>(field('password')).controller!.text,
        ' Secret ',
      );
      api.failure = null;
      api.gate = null;
      expect(find.byType(AppErrorSheet), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('error.sheet.action')));
      expect(api.logins.length, 2);
      expect(api.logins.last, {
        'nickname': 'user@example.com',
        'password': ' Secret ',
      });
      expect(api.token, 'Bearer fixture-auth');
      expect(session.user['username'], previewSelf['username']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('register keeps validation and consent before submitting', (
    tester,
  ) async {
    final api = AuthApi();
    await mount(tester, api: api);
    await choose(tester, 'register');
    final l = tester.element(find.byType(AuthScreen)).l10n;
    expect(find.byType(AppField), findsNWidgets(4));
    await tester.enterText(field('nickname'), 'ab!');
    await pumpUI(tester);
    expect(find.text(l.authNicknameInvalid), findsOneWidget);
    await tester.enterText(field('nickname'), 'valid_name');
    await tester.enterText(field('password'), 'Secret');
    await tester.enterText(field('confirmation'), 'Mismatch');
    await pumpUI(tester);
    expect(find.text(l.passwordsDoNotMatch), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.byKey(const ValueKey('auth.submit')))
          .onPressed,
      isNull,
    );
    await tester.enterText(field('confirmation'), 'Secret');
    await pumpUI(tester);
    await tap(tester, find.byKey(const ValueKey('auth.submit')));
    expect(find.text(l.acceptTheTermsToContinue), findsOneWidget);
    expect(api.logins, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Keychain failure explains the error without claiming the password is wrong',
    (tester) async {
      final api = AuthApi()
        ..storageFailure = PlatformException(
          code: '-34018',
          message: 'private payload',
        );
      await mount(tester, api: api);
      await choose(tester, 'login');
      await tester.enterText(field('nickname'), 'user');
      await tester.enterText(field('password'), 'private password');
      await tap(tester, find.byKey(const ValueKey('auth.submit')));
      final l = tester.element(find.byType(AuthScreen)).l10n;
      expect(find.text(l.errorStorageMessage), findsOneWidget);
      expect(find.text(l.loginFailedPleaseCheckYourCredentials), findsNothing);
      await tap(tester, find.text(l.errorDetails));
      expect(find.text('KEYCHAIN_ENTITLEMENT (-34018)'), findsOneWidget);
      expect(find.textContaining('private payload'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('error.sheet.close')));
      expect(
        tester.widget<TextField>(field('password')).controller!.text,
        'private password',
      );
      expect(api.token, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('password visibility preserves selection and text', (
    tester,
  ) async {
    await mount(tester);
    await choose(tester, 'login');
    await tester.enterText(field('password'), 'a secure password');
    final l = tester.element(find.byType(AuthScreen)).l10n;
    await tap(
      tester,
      find.byWidgetPredicate(
        (w) => w is AppIconButton && w.tooltip == l.showPassword,
      ),
    );
    expect(tester.widget<TextField>(field('password')).obscureText, isFalse);
    expect(
      tester.widget<TextField>(field('password')).controller!.text,
      'a secure password',
    );
    await tap(
      tester,
      find.byWidgetPredicate(
        (w) => w is AppIconButton && w.tooltip == l.hidePassword,
      ),
    );
    expect(tester.widget<TextField>(field('password')).obscureText, isTrue);
  });
  testWidgets(
    'accepted registration with Keychain failure continues as login without registering twice',
    (tester) async {
      final api = AuthApi()..storageFailure = PlatformException(code: '-34018');
      await mount(tester, api: api);
      await choose(tester, 'register');
      await tester.enterText(field('nickname'), 'valid_name');
      await tester.enterText(field('password'), 'Secret');
      await tester.enterText(field('confirmation'), 'Secret');
      await tap(tester, find.byType(AppChoiceRow));
      await tap(tester, find.byKey(const ValueKey('auth.submit')));
      final l = tester.element(find.byType(AuthScreen)).l10n;
      expect(find.text(l.errorAccountCreatedTitle), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('error.sheet.action')));
      expect(find.byKey(const ValueKey('auth.confirmation')), findsNothing);
      api.storageFailure = null;
      await tap(tester, find.byKey(const ValueKey('auth.submit')));
      expect(api.registrations.length, 1);
      expect(api.logins.length, 1);
      expect(api.logins.single['nickname'], 'valid_name');
      expect(api.logins.single['password'], 'Secret');
      expect(tester.takeException(), isNull);
    },
    skip: AppConstants.registrationCaptchaEnabled,
  );
  testWidgets(
    'registration respects the CAPTCHA constant and keeps its draft on cancellation',
    (tester) async {
      final api = AuthApi();
      final session = await mount(tester, api: api);
      await choose(tester, 'register');
      await tester.enterText(field('nickname'), 'valid_name');
      await tester.enterText(field('password'), ' Secret ');
      await tester.enterText(field('confirmation'), ' Secret ');
      await tester.enterText(field('referral'), ' referral_123 ');
      await tap(tester, find.byType(AppChoiceRow));
      final submit = find.byKey(const ValueKey('auth.submit'));
      final navigator = Navigator.of(
        tester.element(find.byType(AuthScreen)),
        rootNavigator: true,
      );
      await tester.ensureVisible(submit);
      await pumpUI(tester);
      await tester.tap(submit);
      if (AppConstants.registrationCaptchaEnabled) {
        expect(api.registrations, isEmpty);
        // Resolve the modal route before its platform WebView is built.
        navigator.pop();
        await pumpUI(tester);
        expect(api.registrations, isEmpty);
        expect(
          tester.widget<TextField>(field('nickname')).controller!.text,
          'valid_name',
        );
        expect(tester.widget<AppButton>(submit).loading, isFalse);
        await tester.tap(submit);
        expect(api.registrations, isEmpty);
        navigator.pop(' verified-token ');
      }
      await pumpUI(tester);
      expect(api.registrations, [
        {
          'nickname': 'valid_name',
          'password': ' Secret ',
          'name': 'valid_name',
          'domain': 'coolvibes.lgbt',
          'referralCode': 'referral_123',
          if (AppConstants.registrationCaptchaEnabled)
            'recaptchaToken': 'verified-token'
          else
            'captcha': 'COOLVIBES',
        },
      ]);
      expect(api.token, 'Bearer fixture-auth');
      expect(session.user['username'], previewSelf['username']);
      expect(tester.takeException(), isNull);
    },
  );
}
