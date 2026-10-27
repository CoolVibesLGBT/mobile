import 'support/source_assets.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/radar_profile_card.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/auth.dart';
import 'package:coolvibes/screens/emoticons.dart';
import 'package:coolvibes/screens/shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;

class AuditApi extends PreviewApi {
  Json? submitted;
  ApiException? loginError;
  bool failReaction = false;
  AuditApi() : super(PreviewState.populated);
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (action == 'test.password') {
      submitted = body;
      return {};
    }
    if (action == 'auth.login' && loginError != null) throw loginError!;
    if (action == 'match.create' && failReaction) {
      throw ApiException.connection('Offline');
    }
    if (action == 'auth.user_info') return {'data': previewSelf};
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

class AuditSession extends Session {
  AuditSession(super.api) : super(persistPreferences: false);
  @override
  void connect() {}
}

/// A control by its accessible label: an AppPressable or a glass button.
Finder press(String label) => find.byWidgetPredicate(
  (w) =>
      (w is AppPressable && w.label == label) ||
      (w is liquid.GlassButton && w.label == label),
);
Finder button(String label) => find.byWidgetPredicate(
  (w) => w is AppButton && w.child is Text && (w.child as Text).data == label,
);

void main() {
  testWidgets(
    'standalone picker exposes real emoji data and returns the selection',
    (tester) async {
      final session = AuditSession(AuditApi())
        ..ready = true
        ..user = previewSelf;
      Json? selected;
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: JsonAssets(),
          child: CoolvibesApp(
            session: session,
            home: EmoticonPicker(onSelected: (value) => selected = value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Picker sections are vendored glass segments, found by their label.
      expect(find.bySemanticsLabel('Emoji'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Emoji'));
      await tester.pumpAndSettle();
      expect(find.text('😀'), findsWidgets);
      await tester.tap(find.text('😀').first);
      await tester.pump();
      expect(selected?['emoji'], '😀');
      expect(session.recentEmoji, contains('😀'));
      await tester.pumpAndSettle();
      // Telegram EmojiSearchSearchBarComponent: categories are faded glyphs in
      // the search bar, not tabs; choosing one filters the grid to that group.
      expect(find.text('Son kullanılanlar'.toUpperCase()), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('emoji.group.love')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('💛').hitTestable(), findsWidgets);
      expect(find.text('😀').hitTestable(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('emoji.group.love')));
      await tester.pumpAndSettle();
      expect(find.text('😀').hitTestable(), findsWidgets);
      tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kalp');
      await tester.pumpAndSettle();
      final emojiCells = tester
          .widgetList<AppPressable>(find.byType(AppPressable))
          .where((cell) => cell.style == AppPressStyle.emoji);
      expect(emojiCells, isNotEmpty);
      expect(emojiCells.every((cell) => cell.label.contains('heart')), isTrue);
      await tester.enterText(find.byType(TextField), 'wave');
      await tester.pumpAndSettle();
      await tester.longPress(find.text('👋'));
      await tester.pumpAndSettle();
      for (final tone in ['👋🏻', '👋🏼', '👋🏽', '👋🏾', '👋🏿']) {
        expect(find.text(tone), findsOneWidget);
      }
      await tester.tap(find.text('👋🏽'));
      await tester.pumpAndSettle();
      expect(selected?['emoji'], '👋🏽');
      expect(session.recentEmoji.first, '👋🏽');

      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('password form preserves whitespace in every password field', (
    tester,
  ) async {
    final api = AuditApi();
    final session = AuditSession(api)..ready = true;
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: const ActionForm(
          title: 'Password',
          action: 'test.password',
          fields: {
            'current_password': 'Current',
            'new_password': 'New',
            'new_password_confirmation': 'Confirm',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), ' current ');
    await tester.enterText(fields.at(1), ' new ');
    await tester.enterText(fields.at(2), ' new ');
    await tester.pump();
    await tester.tap(button('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.submitted, {
      'current_password': ' current ',
      'new_password': ' new ',
      'new_password_confirmation': ' new ',
    });
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'offline login reports connection failure rather than bad credentials',
    (tester) async {
      final api = AuditApi()..loginError = ApiException.connection('Offline');
      final session = AuditSession(api)..ready = true;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: const AuthScreen(showChoices: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.pump();
      await tester.tap(button('Giriş yap'));
      await tester.pumpAndSettle();
      expect(
        find.text('Servise ulaşılamadı. Bağlantını kontrol edip tekrar dene.'),
        findsOneWidget,
      );
      expect(find.byType(AuthScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'startup failure has recovery instead of an empty authenticated shell',
    (tester) async {
      final session = AuditSession(AuditApi())
        ..ready = true
        ..startupError = 'Offline';
      await tester.pumpWidget(CoolvibesApp(session: session));
      await tester.pumpAndSettle();
      expect(find.byType(Shell), findsNothing);
      expect(find.text('Hesabın yüklenemedi.'), findsOneWidget);
      await tester.tap(press('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.byType(Shell), findsOneWidget);
      expect(session.user['public_id'], previewSelf['public_id']);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'failed radar reaction keeps the card and does not publish success',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var closed = false, reacted = false;
      final session = AuditSession(AuditApi()..failReaction = true)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: AppScaffold(
            body: RadarProfileCard(
              user: previewPeer,
              onClose: () => closed = true,
              onReaction: (_) => reacted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(press('Beğen'));
      await tester.pump();
      expect(closed, isFalse);
      expect(reacted, isFalse);
      expect(find.text('Offline'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
