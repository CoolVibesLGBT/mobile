import 'dart:async';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/components/chat_input.dart';
import 'package:coolvibes/components/chat_list_row.dart';
import 'package:coolvibes/components/chat_bubble.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/core/chat_data.dart';
import 'package:coolvibes/screens/auth.dart';
import 'package:coolvibes/screens/shell.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'support/contract_api.dart';
import 'support/ui_driver.dart';

class PendingPostApi extends ContractApi {
  Completer<Json> response = Completer<Json>();
  int posts = 0;
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) {
    if (action == 'post.create') {
      posts++;
      return response.future;
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

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder action(String label) => find.byWidgetPredicate(
  (w) => w is AppButton && w.child is Text && (w.child as Text).data == label,
);

void main() {
  testWidgets(
    'post remains open until acknowledged, preserves text on failure, retries one job',
    (tester) async {
      final api = PendingPostApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(
            builder: (context) => AppScaffold(
              body: Center(
                child: AppButton.text(
                  onPressed: () => sheet(context, const ComposerScreen()),
                  child: const Text('Open composer'),
                ),
              ),
            ),
          ),
        ),
      );
      await tapUI(tester, action('Open composer'));
      await frames(tester);
      final input = find.descendant(
        of: find.byType(MessageField),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, 'Gönderim kaybolmasın');
      await tester.pump();
      await tapUI(tester, find.byKey(const ValueKey('article.send')));
      await frames(tester);
      expect(find.byType(ComposerScreen), findsOneWidget);
      expect(
        tester
            .widget<AppIconButton>(find.byKey(const ValueKey('article.send')))
            .onPressed,
        isNull,
      );
      final jobId = session.uploads.jobs.single.id;
      api.response.completeError(ApiException.connection('Offline'));
      await frames(tester);
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Gönderim kaybolmasın',
      );
      expect(find.text('Offline'), findsOneWidget);
      api.response = Completer<Json>();
      await tapUI(tester, find.byKey(const ValueKey('article.send')));
      await frames(tester);
      expect(session.uploads.jobs.single.id, jobId);
      api.response.complete({'data': previewPost});
      await frames(tester);
      expect(api.posts, 2);
      expect(find.byType(ComposerScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'chat list long press previews the actual conversation without marking read',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ContractApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const ChatsScreen()),
      );
      await frames(tester);
      await tester.longPress(find.byType(ChatListRow).first);
      await frames(tester);
      final preview = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(preview.preview, isTrue);
      expect(find.byType(ChatInput), findsNothing);
      expect(api.calls.where((c) => c.action == 'chat.message_read'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('cancel editing restores the unsent draft and focus', (
    tester,
  ) async {
    final api = ContractApi()
      ..sent.add({
        'id': messageUuid,
        'chat_id': conversation,
        'author_id': previewSelf['public_id'],
        'content': {'tr': 'Existing message'},
        'created_at': '2026-10-24T10:00:00Z',
      });
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: ChatScreen(chat: {...previewChat, 'id': conversation}),
      ),
    );
    await frames(tester);
    final input = find.descendant(
      of: find.byType(MessageField),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, 'Unsent draft');
    await tester.pump();
    await tester.longPress(
      find.textContaining('Existing message', findRichText: true).first,
    );
    await frames(tester);
    await tapUI(tester, find.text('Düzenle'));
    await frames(tester);
    expect(
      tester.widget<TextField>(input).controller!.text,
      'Existing message',
    );
    await tapUI(
      tester,
      find.byWidgetPredicate(
        (w) => w is AppPressable && w.label == 'Düzenlemeyi iptal et',
      ),
    );
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, 'Unsent draft');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets(
    'multiple selection forwards both UUIDs and overlays the composer on the list',
    (tester) async {
      const second = 'ac406ac6-1c1c-4319-8f18-6f2e78e2a1ec';
      final api = ContractApi()
        ..sent.addAll([
          {
            'id': messageUuid,
            'chat_id': conversation,
            'author_id': previewSelf['public_id'],
            'content': {'tr': 'First selection'},
            'created_at': '2026-10-24T10:00:00Z',
          },
          {
            'id': second,
            'chat_id': conversation,
            'author_id': previewSelf['public_id'],
            'content': {'tr': 'Second selection'},
            'created_at': '2026-10-24T10:01:00Z',
          },
        ]);
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: ChatScreen(chat: {...previewChat, 'id': conversation}),
        ),
      );
      await frames(tester);
      final listBounds = tester.getRect(find.byType(ListView).first);
      final inputBounds = tester.getRect(find.byType(ChatInput));
      expect(listBounds.bottom, greaterThan(inputBounds.top));
      expect(listBounds.bottom, closeTo(inputBounds.bottom, 1));
      await tester.longPress(
        find.textContaining('First selection', findRichText: true),
      );
      await frames(tester);
      await tapUI(tester, find.text('Seç'));
      await frames(tester);
      expect(find.text('1 Seçildi'), findsOneWidget);
      // Selection mode: tapping anywhere on a row toggles it.
      await tapUI(
        tester,
        find.textContaining('Second selection', findRichText: true),
      );
      await frames(tester);
      expect(find.text('2 Seçildi'), findsOneWidget);
      expect(
        tester
            .widgetList<ChatBubble>(find.byType(ChatBubble))
            .where((w) => w.selected == true)
            .length,
        2,
      );
      await tapUI(
        tester,
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Seçili mesajları ilet',
        ),
      );
      await frames(tester);
      expect(find.byType(ForwardScreen), findsOneWidget);
      // Choosing this same chat keeps both messages in the forward panel.
      await tapUI(tester, find.text(chatTitle(previewChat, previewSelf)).last);
      await frames(tester);
      expect(find.text('2 Mesajı İlet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'long press forwards to the selected conversation and confirms success',
    (tester) async {
      const target = '8709d7b7-ea40-4caf-bacc-958a929c8250';
      final api = ContractApi()
        ..chats.add({
          ...previewChat,
          'id': target,
          'public_id': '3002',
          'type': 'group',
          'title': 'Forward target',
        })
        ..sent.add({
          'id': messageUuid,
          'chat_id': conversation,
          'author_id': previewSelf['public_id'],
          'content': {'tr': 'Forward this message'},
          'created_at': '2026-10-24T10:00:00Z',
        });
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: ChatScreen(chat: {...previewChat, 'id': conversation}),
        ),
      );
      await frames(tester);
      await tester.longPress(
        find.textContaining('Forward this message', findRichText: true).first,
      );
      await frames(tester);
      expect(
        tester
            .widget<GlassSurface>(
              find.byKey(const ValueKey('context.actions.surface')),
            )
            .role,
        GlassSurfaceRole.menu,
      );
      await tapUI(tester, find.text('İlet'));
      await frames(tester);
      expect(find.byType(ForwardScreen), findsOneWidget);
      await tapUI(tester, find.text('Forward target'));
      await frames(tester);
      // Telegram: the target chat opens with the forward accessory panel and
      // nothing is sent until the user presses send (with an optional comment).
      expect(
        api.calls.where((c) => c.action == 'chat.forward_messages'),
        isEmpty,
      );
      expect(find.text('Mesajı İlet'), findsOneWidget);
      final input = find
          .descendant(
            of: find.byType(MessageField),
            matching: find.byType(TextField),
          )
          .last;
      await tester.enterText(input, 'Bak buna');
      await tester.pump();
      await tapUI(
        tester,
        find
            .byWidgetPredicate(
              (w) => w is AppIconButton && w.tooltip == 'Gönder',
            )
            .last,
      );
      await frames(tester);
      final request = api.calls.singleWhere(
        (c) => c.action == 'chat.forward_messages',
      );
      expect(request.body, {
        'source_chat_id': conversation,
        'chat_id': target,
        'message_ids[]': [messageUuid],
        'content': 'Bak buna',
      });
      expect(find.text('Mesajı İlet'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('message edit and delete use the original message identity', (
    tester,
  ) async {
    final api = ContractApi()
      ..sent.add({
        'id': messageUuid,
        'chat_id': conversation,
        'author_id': previewSelf['public_id'],
        'content': {'tr': 'Before edit'},
        'created_at': '2026-10-24T10:00:00Z',
      });
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: ChatScreen(chat: {...previewChat, 'id': conversation}),
      ),
    );
    await frames(tester);
    await tester.longPress(
      find.textContaining('Before edit', findRichText: true).first,
    );
    await frames(tester);
    await tapUI(tester, find.text('Düzenle'));
    await frames(tester);
    final input = find.descendant(
      of: find.byType(MessageField),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, 'After edit');
    await tester.pump();
    await tapUI(
      tester,
      find.byWidgetPredicate(
        (w) =>
            (w is AppPressable && w.label == 'Kaydet') ||
            (w is liquid.GlassButton && w.label == 'Kaydet'),
      ),
    );
    await frames(tester);
    final edit = api.calls.singleWhere((c) => c.action == 'chat.edit_message');
    expect(edit.body['message_id'], messageUuid);
    expect(edit.body['content'], 'After edit');
    expect(
      find.textContaining('After edit', findRichText: true),
      findsOneWidget,
    );
    await tester.longPress(
      find.textContaining('After edit', findRichText: true).first,
    );
    await frames(tester);
    // The shared confirmation sheet preserves the two deletion scopes.
    await tapUI(tester, find.text('Sil'));
    await frames(tester);
    expect(find.text('Herkesten sil'), findsOneWidget);
    expect(find.byType(AppConfirmationSheet), findsOneWidget);
    expect(find.byType(AppInfoSheet), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirmation.sheet.cancel')),
    );
    await tapUI(
      tester,
      find.byKey(const ValueKey('confirmation.sheet.cancel')),
    );
    await frames(tester);
    expect(
      api.calls.where((c) => c.action.startsWith('chat.delete_message')),
      isEmpty,
    );
    expect(
      find.textContaining('After edit', findRichText: true),
      findsOneWidget,
    );
    await tester.longPress(
      find.textContaining('After edit', findRichText: true),
    );
    await frames(tester);
    await tapUI(tester, find.text('Sil'));
    await frames(tester);
    await tapUI(tester, find.text('Herkesten sil'));
    await frames(tester);
    expect(
      api.calls
          .singleWhere((c) => c.action == 'chat.delete_message_for_all')
          .body,
      {'chat_id': conversation, 'message_id': messageUuid},
    );
    expect(find.textContaining('After edit', findRichText: true), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets(
    'chat list delete addresses the selected conversation and refreshes',
    (tester) async {
      final api = ContractApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const ChatsScreen()),
      );
      await frames(tester);
      await tester.longPress(find.byType(ChatListRow).first);
      await frames(tester);
      await tapUI(tester, find.text('Sil').last);
      await frames(tester);
      expect(
        api.calls
            .singleWhere((c) => c.action == 'chat.delete_chat_for_user')
            .body,
        {'chat_id': conversation},
      );
      expect(find.byType(ChatListRow), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'logout dismisses private conversation routes and context previews',
    (tester) async {
      final api = ContractApi()
        ..sent.add({
          'id': messageUuid,
          'chat_id': conversation,
          'author_id': previewSelf['public_id'],
          'content': {'tr': 'Private message'},
          'created_at': '2026-10-24T10:00:00Z',
        });
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(CoolvibesApp(session: session));
      await frames(tester);
      unawaited(
        open(
          tester.element(find.byType(Shell)),
          ChatScreen(chat: {...previewChat, 'id': conversation}),
        ),
      );
      await frames(tester);
      await tester.longPress(
        find.textContaining('Private message', findRichText: true).first,
      );
      await frames(tester);
      expect(find.text('Kopyala'), findsOneWidget);
      final logout = session.logout();
      await frames(tester);
      await logout;
      await frames(tester);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.text('Kopyala'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
