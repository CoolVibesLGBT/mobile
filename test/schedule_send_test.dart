import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'support/contract_api.dart';

void main() {
  testWidgets(
    'long-press send schedules the message with scheduled_at and keeps it '
    'out of the history',
    (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
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
      Future<void> frames() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await frames();
      final input = find.descendant(
        of: find.byType(MessageField),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, 'Yarın görüşelim');
      await tester.pump();
      final send = find.byWidgetPredicate(
        (w) => w is AppIconButton && w.tooltip == 'Gönder',
      );
      await tester.longPress(send);
      await frames();
      await tester.tap(find.text('Mesajı Zamanla'));
      await frames();
      expect(find.byType(ScheduleMessageSheet), findsOneWidget);
      await tester.tap(find.textContaining('gönder').last);
      await frames();
      await frames();
      final request = api.calls.lastWhere(
        (c) => c.action == 'chat.send_message',
      );
      expect(request.body['content'], 'Yarın görüşelim');
      final at = DateTime.parse('${request.body['scheduled_at']}');
      expect(at.isAfter(DateTime.now().toUtc()), isTrue);
      // A scheduled send never lands in the visible history.
      expect(
        find.textContaining('Yarın görüşelim', findRichText: true),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
