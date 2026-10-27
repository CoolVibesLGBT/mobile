import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/app_lottie.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/auth.dart';
import 'package:coolvibes/screens/settings.dart';
import 'support/ui_driver.dart';

class AccountApi extends PreviewApi {
  AccountApi() : super(PreviewState.populated);
  final actions = <String>[];
  bool rejectDeletion = false;
  Completer<Json>? deletion;
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (action == 'auth.logout' || action == 'user.delete_profile') {
      actions.add(action);
      if (action == 'user.delete_profile') {
        if (rejectDeletion) throw ApiException('Unavailable', 503);
        if (deletion != null) return deletion!.future;
      }
      return {'success': true, 'data': {}};
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
  WidgetTester tester,
  AccountApi api, {
  bool accessible = false,
}) async {
  tester.view.physicalSize = accessible
      ? const Size(320, 568)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  if (accessible) {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }
  final session = Session(api, persistPreferences: false)
    ..ready = true
    ..user = previewSelf
    ..locale = Locale(accessible ? 'ar' : 'tr')
    ..themeMode = accessible ? ThemeMode.dark : ThemeMode.light;
  await tester.pumpWidget(
    CoolvibesApp(
      session: session,
      home: Builder(
        builder: (context) => AppScope.of(context).api.token == null
            ? const AuthScreen()
            : const SettingsScreen(),
      ),
    ),
  );
  await pumpUI(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  return session;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await pumpNativeFrames(tester);
  await tester.tap(target);
  await pumpUI(tester);
}

void main() {
  for (final action in ['logout', 'deleteAccount']) {
    testWidgets(
      '$action uses the animated info sheet and cancel never mutates the account',
      (tester) async {
        final api = AccountApi();
        final session = await mount(
          tester,
          api,
          accessible: action == 'deleteAccount',
        );
        final token = api.token;
        await tapKey(tester, 'settings.$action');
        expect(find.byType(AppConfirmationSheet), findsOneWidget);
        expect(find.byType(AppInfoSheet), findsOneWidget);
        expect(
          tester.widget<AppLottie>(find.byType(AppLottie)).asset,
          'assets/animations/restricted.json',
        );
        expect(api.actions, isEmpty);
        await tapKey(tester, 'confirmation.sheet.cancel');
        expect(api.actions, isEmpty);
        expect(api.token, token);
        expect(session.user, previewSelf);
        await tapKey(tester, 'settings.$action');
        await tapKey(tester, 'confirmation.sheet.close');
        expect(api.actions, isEmpty);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'confirmed logout clears the session without deleting the account',
    (tester) async {
      final api = AccountApi();
      final session = await mount(tester, api);
      await tapKey(tester, 'settings.logout');
      await tapKey(tester, 'confirmation.sheet.confirm');
      expect(api.actions, ['auth.logout']);
      expect(api.token, isNull);
      expect(session.user, isEmpty);
      expect(find.byType(AuthScreen), findsOneWidget);
    },
  );

  testWidgets(
    'deletion preserves the session on failure and waits for server success',
    (tester) async {
      final api = AccountApi()..rejectDeletion = true;
      final session = await mount(tester, api);
      final token = api.token;
      await tapKey(tester, 'settings.deleteAccount');
      await tapKey(tester, 'confirmation.sheet.confirm');
      expect(api.actions, ['user.delete_profile']);
      expect(api.token, token);
      expect(session.user, previewSelf);
      expect(find.byType(AppErrorSheet), findsOneWidget);
      await tapKey(tester, 'error.sheet.close');
      api.rejectDeletion = false;
      api.deletion = Completer<Json>();
      await tapKey(tester, 'settings.deleteAccount');
      await tapKey(tester, 'confirmation.sheet.confirm');
      expect(api.actions.length, 2);
      expect(api.token, token);
      expect(
        tester
            .widget<AppRow>(
              find.byKey(const ValueKey('settings.deleteAccount')),
            )
            .onTap,
        isNull,
      );
      api.deletion!.complete({'success': true, 'data': {}});
      await pumpUI(tester);
      expect(api.token, isNull);
      expect(session.user, isEmpty);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
