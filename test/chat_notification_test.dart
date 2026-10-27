import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/chat_input.dart';
import 'package:coolvibes/components/chat_list_row.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'support/contract_api.dart';
import 'support/ui_driver.dart';

void main() {
  testWidgets(
    'forward success stays above a resizing composer and leaves the input tappable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.reset);
      final api = ContractApi()
        ..chats.add({...previewGroup, 'id': 'target-group'})
        ..sent.add({
          'id': messageUuid,
          'chat_id': conversation,
          'author_id': previewSelf['public_id'],
          'content': {'tr': 'Forward notification test'},
          'created_at': '2026-10-26T10:00:00Z',
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
      await pumpUI(tester);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      });
      await tester.longPress(
        find.textContaining('Forward notification test', findRichText: true),
      );
      await pumpUI(tester);
      await tester.tap(find.text('İlet'));
      await pumpUI(tester);
      await tester.tap(find.byKey(const ValueKey('forward.select')));
      await pumpUI(tester);
      await tester.tap(find.byType(ChatListRow).first);
      await pumpUI(tester);
      await tester.tap(find.byType(ChatListRow).last);
      await pumpUI(tester);
      await tester.tap(find.byKey(const ValueKey('forward.send')));
      await pumpUI(tester);
      final notice = find.text('2 sohbete iletildi');
      expect(notice, findsOneWidget);
      final noticeSurface = find
          .ancestor(of: notice, matching: find.byType(Material))
          .first;
      void checkPosition() {
        final composer = tester.getRect(find.byType(ChatInput));
        final bubble = tester.getRect(noticeSurface);
        expect(bubble.bottom, lessThanOrEqualTo(composer.top));
        expect(composer.top - bubble.bottom, closeTo(10, 1));
        expect(bubble.top, greaterThan(0));
      }

      checkPosition();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding(top: 59);
      await pumpNativeFrames(tester);
      checkPosition();
      final field = find.descendant(
        of: find.byType(MessageField),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(
        field,
        'Line one\nLine two\nLine three\nLine four',
      );
      await pumpNativeFrames(tester);
      checkPosition();
      expect(tester.takeException(), isNull);
    },
  );
}
