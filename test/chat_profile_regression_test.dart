import 'dart:io';
import 'package:coolvibes/components/app_pressable.dart';
import 'package:coolvibes/components/app_segments.dart';
import 'support/contract_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/chat_data.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/screens/profile.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:coolvibes/screens/emoticons.dart';
import 'package:coolvibes/screens/media.dart';
import 'package:coolvibes/components/app_image.dart';
import 'package:coolvibes/components/avatar.dart';
import 'package:coolvibes/components/message_field.dart';

class SourceAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      key.endsWith('.json') && File(key).existsSync()
      ? Future<String>.value(File(key).readAsStringSync())
      : rootBundle.loadString(key, cache: cache);
}

/// A control by its accessible label: an AppPressable or a glass button.
Finder control(String label) => find.byWidgetPredicate(
  (w) =>
      (w is AppPressable && w.label == label) ||
      (w is liquid.GlassButton && w.label == label),
);
Future<void> finishFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test(
    'chat identity, participants and localized titles follow real server projection',
    () {
      expect(chatEntityId({'id': messageUuid, 'public_id': '12'}), messageUuid);
      final chat = {
        'title': <String, dynamic>{},
        'participants': [
          {'user': previewSelf},
          {'user': previewPeer},
        ],
      };
      expect(chatPeer(chat, previewSelf)['username'], previewPeer['username']);
      expect(chatTitle(chat, previewSelf), previewPeer['displayname']);
      expect(
        chatTitle({
          'title': {'tr': 'Türkçe', 'en': 'English'},
        }, previewSelf),
        'Türkçe',
      );
      expect(
        messageIsMine({'author_id': previewSelf['public_id']}, previewSelf),
        isTrue,
      );
      expect(
        messageIsMine({'author_id': previewPeer['public_id']}, previewSelf),
        isFalse,
      );
    },
  );
  testWidgets(
    'failed queued message stays visible; retry uses UUID and same client id',
    (tester) async {
      final api = ContractApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: ChatScreen(
            chat: {
              ...previewChat,
              'id': conversation,
              'public_id': 'wrong-public-chat-id',
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final field = find.descendant(
        of: find.byType(MessageField),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Merhaba Coolvibes');
      await tester.pump();
      await tester.tap(control('Gönder'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(
        find.textContaining('Merhaba Coolvibes', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Mesaj gönderilemedi. Yeniden denemek için dokun.',
        ),
        findsOneWidget,
      );
      api.failSend = false;
      await tester.tap(
        find.bySemanticsLabel(
          'Mesaj gönderilemedi. Yeniden denemek için dokun.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final sends = api.calls
          .where((c) => c.action == 'chat.send_message')
          .toList();
      expect(sends.length, 2);
      expect(sends[0].body['chat_id'], conversation);
      expect(sends[0].body['client_id'], sends[1].body['client_id']);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(
        find.textContaining('Merhaba Coolvibes', findRichText: true),
        findsOneWidget,
      );
      final reads = api.calls.where((c) => c.action == 'chat.message_read');
      expect(reads.last.body['message_ids[]'], [messageUuid]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      session.dispose();
    },
  );
  testWidgets(
    'direct auth user payload renders own profile and correct posts owner',
    (tester) async {
      final api = ContractApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const ProfileScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(session.user['public_id'], previewSelf['public_id']);
      expect(find.text('@${previewSelf['username']}'), findsOneWidget);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
      await finishFrames(tester);
      await tester.ensureVisible(find.text('Gönderiler'));
      await tester.pump();
      await tester.tap(find.text('Gönderiler'));
      await finishFrames(tester);
      expect(
        tester
            .widget<AppSegments<String>>(find.byType(AppSegments<String>))
            .selected,
        'posts',
      );
      final request = api.calls
          .where((c) => c.action == 'user.fetch.posts')
          .last;
      expect(request.body['user_id'], previewSelf['public_id']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'Nearby sends coordinates, uses square cards and switches to list',
    (tester) async {
      final api = ContractApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const NearbyScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final request = api.calls
          .where((c) => c.action == 'user.fetch.nearby.users')
          .last;
      expect(request.body['latitude'], 41.0082);
      expect(request.body['longitude'], 28.9784);
      expect(
        tester.widgetList<Avatar>(find.byType(Avatar)).any((a) => a.rounded),
        isTrue,
      );
      await tester.tap(find.bySemanticsLabel('Liste'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widgetList<Avatar>(find.byType(Avatar)).any((a) => a.rounded),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  for (final post in [false, true]) {
    testWidgets(
      '${post ? 'post' : 'chat'} shares editor and fits open keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final session = Session(ContractApi(), persistPreferences: false)
          ..ready = true
          ..user = previewSelf;
        await tester.pumpWidget(
          CoolvibesApp(
            session: session,
            home: post
                ? const ComposerScreen()
                : ChatScreen(chat: {...previewChat, 'id': conversation}),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final field = find.descendant(
          of: find.byType(MessageField),
          matching: find.byType(TextField),
        );
        await tester.enterText(field, 'Birinci satır\nİkinci satır');
        await tester.pump(const Duration(milliseconds: 400));
        final fields = tester.widgetList<TextField>(field).toList();
        expect(fields.every((input) => input.style!.fontSize == 17), isTrue);
        expect(
          fields.map((input) => input.controller!.text).join(post ? '\n' : ''),
          'Birinci satır\nİkinci satır',
        );
        expect(tester.getRect(field.last).bottom, lessThanOrEqualTo(387));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        session.dispose();
      },
    );
  }
  testWidgets(
    'emoji panel inserts at cursor and returns focus without a modal route',
    (tester) async {
      final session = Session(ContractApi(), persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: SourceAssetBundle(),
          child: CoolvibesApp(
            session: session,
            home: ChatScreen(chat: {...previewChat, 'id': conversation}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final field = find.descendant(
        of: find.byType(MessageField),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Merhaba');
      await tester.tap(control('Emoji, Sticker ve GIF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byType(EmoticonPicker), findsOneWidget);
      expect(
        tester.widget<EmoticonPicker>(find.byType(EmoticonPicker)).embedded,
        isTrue,
      );
      await tester.tap(find.text('😀'));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'Merhaba😀');
      await tester.tap(control('Klavyeyi göster').last);
      await tester.pump();
      expect(find.byType(EmoticonPicker), findsNothing);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      session.dispose();
    },
  );
  testWidgets('new chat unwraps friendships and sends the peer public id', (
    tester,
  ) async {
    final api = ContractApi();
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const NewChatScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Ege'));
    await tester.pump();
    await tester.tap(find.text('Oluştur'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ChatScreen), findsOneWidget);
    final create = api.calls.where((c) => c.action == 'chat.create').single;
    expect(create.body['participant_ids[]'], [previewPeer['public_id']]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    session.dispose();
  });
  testWidgets(
    'received voice and documents use controls instead of image loaders',
    (tester) async {
      final session = Session(ContractApi(), persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Scaffold(
            body: Column(
              children: [
                MediaAttachments(
                  record: {
                    'attachments': [
                      {
                        'url': 'https://example.invalid/voice.m4a',
                        'file': {'name': 'voice.m4a', 'mime_type': 'audio/mp4'},
                      },
                    ],
                  },
                ),
                MediaAttachments(
                  record: {
                    'attachments': [
                      {
                        'url': 'https://example.invalid/document.pdf',
                        'file': {
                          'name': 'document.pdf',
                          'mime_type': 'application/pdf',
                          'size': 2048,
                        },
                      },
                    ],
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(control('Oynat'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('document.pdf'), findsOneWidget);
      expect(find.text('application/pdf · 2 KB'), findsOneWidget);
      expect(find.byType(AppImage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
