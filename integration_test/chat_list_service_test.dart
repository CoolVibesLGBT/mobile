import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/components/chat_list_row.dart';
import 'package:coolvibes/components/record_list.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('authorized chat list renders the service last-message previews', (
    tester,
  ) async {
    await liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
    final api = Api();
    await api.restore();
    expect(
      api.token?.isNotEmpty,
      isTrue,
      reason: 'Existing simulator login required',
    );
    final auth = await api.call('auth.user_info');
    final data = object(auth['data']);
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = object(data['user'] ?? data);
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const ChatsScreen()),
    );
    await tester.pump();
    final list = tester.state<RecordListState>(find.byType(RecordList));
    for (var i = 0; i < 100 && !list.loaded && list.error == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(list.error == null, isTrue, reason: 'Chat list service read failed');
    expect(list.loaded, isTrue);
    var messages = 0, attachments = 0, missing = 0;
    for (final chat in list.records) {
      final last = object(chat['last_message']);
      if (last.isEmpty) continue;
      messages++;
      if ((last['attachments'] as List? ?? []).isNotEmpty) attachments++;
      final row = chatRow(
        tester.element(find.byType(ChatsScreen)),
        chat,
        onTap: () {},
      );
      if (row.preview.trim().isEmpty) missing++;
    }
    debugPrint(
      'CHAT_LIST_SERVICE rows=${list.records.length} messages=$messages attachments=$attachments missing_previews=$missing',
    );
    expect(missing, 0);
    expect(find.byType(ChatListRow), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    api.dio.close();
  }, skip: !const bool.fromEnvironment('CHAT_LIST_SERVICE'));
}
