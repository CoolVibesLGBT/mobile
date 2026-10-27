import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/chat_input.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/core/attachments.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'support/contract_api.dart';
import 'support/ui_driver.dart';

Finder editor() => find.descendant(
  of: find.byType(MessageField),
  matching: find.byType(TextField),
);

Future<ContractApi> openChat(WidgetTester tester) async {
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
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  return api;
}

void main() {
  for (final action in ['enter', 'numpadEnter', 'send']) {
    testWidgets('$action sends one chat message and retains input focus', (
      tester,
    ) async {
      final api = await openChat(tester);
      await tester.enterText(editor(), 'Merhaba 👋');
      await tester.pump();
      if (action == 'send') {
        await tester.testTextInput.receiveAction(TextInputAction.send);
      } else {
        final key = action == 'enter'
            ? LogicalKeyboardKey.enter
            : LogicalKeyboardKey.numpadEnter;
        await tester.sendKeyDownEvent(key);
        await tester.sendKeyRepeatEvent(key);
        await tester.sendKeyUpEvent(key);
      }
      await pumpUI(tester);
      final sends = api.calls
          .where((call) => call.action == 'chat.send_message')
          .toList();
      expect(sends, hasLength(1));
      expect(sends.single.body['content'], 'Merhaba 👋');
      expect(sends.single.body['chat_id'], conversation);
      expect(tester.widget<TextField>(editor()).controller!.text, isEmpty);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Shift+Enter replaces the selection with a newline; Enter sends the multiline draft',
    (tester) async {
      final api = await openChat(tester);
      await tester.enterText(editor(), 'Bir iki üç');
      final controller = tester.widget<TextField>(editor()).controller!;
      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 7,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(controller.text, 'Bir \n üç');
      expect(controller.selection.baseOffset, 5);
      expect(
        api.calls.where((call) => call.action == 'chat.send_message'),
        isEmpty,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpUI(tester);
      final sends = api.calls.where(
        (call) => call.action == 'chat.send_message',
      );
      expect(sends.single.body['content'], 'Bir \n üç');
      expect(controller.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Enter cannot submit blank text or an uncommitted IME composition',
    (tester) async {
      final api = await openChat(tester);
      await tester.enterText(editor(), '   ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(
        api.calls.where((call) => call.action == 'chat.send_message'),
        isEmpty,
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(
        api.calls.where((call) => call.action == 'chat.send_message'),
        isEmpty,
      );
      expect(tester.widget<TextField>(editor()).controller!.text, 'ni');
      await tester.enterText(editor(), '你');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpUI(tester);
      expect(
        api.calls
            .where((call) => call.action == 'chat.send_message')
            .single
            .body['content'],
        '你',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard submission uses the composer busy, attachment and edit guards',
    (tester) async {
      final session = Session(
        PreviewApi(PreviewState.empty),
        persistPreferences: false,
      )..ready = true;
      final text = TextEditingController(text: 'Draft');
      final focus = FocusNode();
      final attachments = AttachmentController();
      final mode = ValueNotifier(0);
      var sends = 0;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: mode,
              builder: (context, value, _) => Align(
                alignment: Alignment.bottomCenter,
                child: ChatInput(
                  controller: text,
                  focusNode: focus,
                  attachments: attachments,
                  sending: value == 0,
                  editing: value == 3,
                  hasExtraContent: value == 4,
                  onSend: () => sends++,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        text.dispose();
        focus.dispose();
        attachments.dispose();
        mode.dispose();
      });
      await pumpUI(tester);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sends, 0);
      text.clear();
      attachments.emoticon = {'kind': 'sticker', 'id': 'fixture-sticker'};
      mode.value = 1;
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sends, 1);
      mode.value = 3;
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(
        sends,
        1,
        reason: 'Editing cannot replace a message with empty text.',
      );
      attachments.clear();
      mode.value = 4;
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sends, 2, reason: 'Forwarding can submit without a comment.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded post editor keeps ordinary multiline keyboard editing',
    (tester) async {
      final session = Session(
        PreviewApi(PreviewState.empty),
        persistPreferences: false,
      )..ready = true;
      final text = TextEditingController();
      final attachments = AttachmentController();
      var sends = 0;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Scaffold(
            body: ChatInput(
              controller: text,
              attachments: attachments,
              sending: false,
              expanded: true,
              onSend: () => sends++,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await pumpUI(tester);
      await tester.enterText(editor(), 'First\nSecond');
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pump();
      expect(text.text, 'First\nSecond');
      expect(sends, 0);
      expect(
        tester.widget<TextField>(editor()).textInputAction,
        TextInputAction.newline,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      text.dispose();
      attachments.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
