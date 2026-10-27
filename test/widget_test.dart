import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/main.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/app_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Turkish authentication with current bundled branding', (
    tester,
  ) async {
    final session = Session(Api())..ready = true;
    await tester.pumpWidget(CoolvibesApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Giriş yap'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auth.choice.login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Giriş yap'), findsNWidgets(2));
    expect(find.text('Kullanıcı adı'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/auth/login-bear.png')),
      findsOneWidget,
    );
    final action = tester.widget<AppButton>(
      find.byKey(const ValueKey('auth.submit')),
    );
    expect(action.onPressed, isNull);
    final fields = find.descendant(
      of: find.byType(AppField),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(1), 'secret');
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, 'secret');
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets('supports RTL and enlarged text without overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = Session(Api())
      ..ready = true
      ..locale = const Locale('ar');
    await tester.pumpWidget(CoolvibesApp(session: session));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('auth.choice.login')),
      150,
    );
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('تسجيل الدخول').first)),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
