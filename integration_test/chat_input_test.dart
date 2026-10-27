import 'support/native_frames.dart';
import 'package:coolvibes/components/app_pressable.dart';
import 'package:coolvibes/screens/profile.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/components/avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:coolvibes/screens/emoticons.dart';
import 'package:coolvibes/components/navigation.dart';
import '../test/support/contract_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  testWidgets(
    'iOS glass send control submits exactly once and clears the editor',
    (tester) async {
      final api = ContractApi()..failSend = false;
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: ChatScreen(chat: {...previewChat, 'id': conversation}),
        ),
      );
      await pumpUI(tester);
      final field = find.descendant(
        of: find.byType(MessageField),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Native iOS gönderim kontrolü');
      await pumpUI(tester);
      final send = find.byWidgetPredicate(
        (widget) => widget is AppIconButton && widget.tooltip == 'Gönder',
      );
      expect(send, findsOneWidget);
      await pumpNativeFrames(tester);
      final sendCenter = tester.getCenter(send);
      await nativeTouch(
        tester,
        sendCenter,
        sendCenter + const Offset(-180, -80),
      );
      await tester.pump();
      expect(
        api.calls.where((call) => call.action == 'chat.send_message'),
        isEmpty,
      );
      await nativeTap(tester, send);
      await pumpUI(tester);
      await pumpNativeFrames(tester);
      final sends = api.calls
          .where((call) => call.action == 'chat.send_message')
          .toList();
      expect(sends.length, 1);
      expect(sends.single.body['chat_id'], conversation);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byType(MessageField),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(
        find.textContaining('Native iOS gönderim kontrolü', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      session.dispose();
    },
  );
  testWidgets('iOS glass post Share queues the same text editor content once', (
    tester,
  ) async {
    final api = ContractApi();
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => open(context, const ComposerScreen()),
                child: const Text('Open post'),
              ),
            ),
          ),
        ),
      ),
    );
    await pumpUI(tester);
    await nativeTap(tester, find.text('Open post'));
    await pumpUI(tester);
    expect(find.byType(ComposerScreen), findsOneWidget);
    final field = find.descendant(
      of: find.byType(MessageField),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Native iOS gönderi kontrolü');
    await pumpUI(tester);
    await pumpNativeFrames(tester);
    await nativeTap(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is AppButton &&
            w.child is Text &&
            (w.child as Text).data == 'Paylaş',
      ),
    );
    await pumpUI(tester);
    final posts = api.calls
        .where((call) => call.action == 'post.create')
        .toList();
    expect(posts.length, 1);
    expect(
      plainText(posts.single.body['content']),
      'Native iOS gönderi kontrolü',
    );
    expect(find.text('Open post'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    session.dispose();
  });
  testWidgets(
    'iOS emoji panel returns to keyboard and sends the inserted emoji',
    (tester) async {
      final api = ContractApi()..failSend = false;
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: ChatScreen(chat: {...previewChat, 'id': conversation}),
        ),
      );
      await pumpUI(tester);
      final field = find.descendant(
        of: find.byType(MessageField),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Merhaba');
      final emoji = find.byWidgetPredicate(
        (w) => w is AppPressable && w.label == 'Emoji, Sticker ve GIF',
      );
      await nativeTap(tester, emoji);
      await pumpUI(tester);
      expect(find.byType(EmoticonPicker), findsOneWidget);
      await pumpNativeFrames(tester);
      await nativeTap(tester, find.text('😀'));
      await pumpUI(tester);
      expect(tester.widget<TextField>(field).controller!.text, 'Merhaba😀');
      await nativeTap(
        tester,
        find
            .byWidgetPredicate(
              (w) => w is AppPressable && w.label == 'Klavyeyi göster',
            )
            .first,
      );
      await pumpUI(tester);
      expect(find.byType(EmoticonPicker), findsNothing);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byType(MessageField),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await nativeTap(
        tester,
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Gönder',
        ),
      );
      await pumpUI(tester);
      final sent = api.calls
          .where((c) => c.action == 'chat.send_message')
          .toList();
      expect(sent.length, 1);
      expect(sent.single.body['content'], 'Merhaba😀');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      session.dispose();
    },
  );
  testWidgets('iOS profile parses the direct auth user payload', (
    tester,
  ) async {
    final api = ContractApi();
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const ProfileScreen()),
    );
    await pumpUI(tester);
    expect(find.text('@${previewSelf['username']}'), findsOneWidget);
    await pumpNativeFrames(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    session.dispose();
  });
  testWidgets('iOS nearby uses square photos and switches to list', (
    tester,
  ) async {
    final api = ContractApi();
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const NearbyScreen()),
    );
    await pumpUI(tester);
    expect(
      tester.widgetList<Avatar>(find.byType(Avatar)).any((a) => a.rounded),
      isTrue,
    );
    await pumpNativeFrames(tester);
    final segments = find.byWidgetPredicate(
      (w) => w is UiKitView && w.viewType == 'coolvibes/segments',
    );
    final bounds = tester.getRect(segments);
    // Grid, list, map: tap the actual native control's middle segment.
    await nativeTouch(tester, bounds.center);
    await pumpUI(tester);
    expect(
      tester.widgetList<Avatar>(find.byType(Avatar)).any((a) => a.rounded),
      isFalse,
    );
    await pumpNativeFrames(tester);
    await nativeTap(
      tester,
      find
          .byWidgetPredicate(
            (w) => w is AppIconButton && w.tooltip == 'Sohbet, Ege',
          )
          .first,
    );
    await pumpUI(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(
      api.calls
          .where((c) => c.action == 'chat.create')
          .last
          .body['participant_ids[]'],
      [previewPeer['public_id']],
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    session.dispose();
  });
  testWidgets(
    'iOS new chat selects a nested friendship and creates a conversation',
    (tester) async {
      final api = ContractApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const NewChatScreen()),
      );
      await pumpUI(tester);
      await pumpNativeFrames(tester);
      await nativeTap(tester, find.text('Ege'));
      await pumpUI(tester);
      await nativeTap(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is AppButton &&
              w.child is Text &&
              (w.child as Text).data == 'Oluştur',
        ),
      );
      await pumpUI(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(
        api.calls
            .where((c) => c.action == 'chat.create')
            .single
            .body['participant_ids[]'],
        [previewPeer['public_id']],
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      session.dispose();
    },
  );
}
