import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/classified_data.dart';
import 'package:coolvibes/core/notification_data.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/screens/classifieds.dart';
import 'package:coolvibes/screens/notifications.dart';
import '../test/support/ui_driver.dart';

Future<void> loaded(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  testWidgets(
    'local service classified detail IDs and authenticated notifications render',
    (tester) async {
      final api = Api();
      await api.restore();
      final session = Session(api, persistPreferences: false)..ready = true;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const ClassifiedsScreen()),
      );
      await tester.pump();
      final list = tester.state<RecordListState>(find.byType(RecordList));
      await loaded(tester, () => list.loaded || list.error != null);
      expect(list.error, isNull);
      expect(list.records, isNotEmpty);
      var details = 0, untitled = 0;
      for (final item in list.records.take(10)) {
        final response = await api.call(
          'classifieds.get',
          body: {'post_id': recordId(item)},
        );
        final detail = classifiedFromResponse(response, recordId(item));
        expect(detail, isNotNull);
        expect(classifiedTitle(detail!, 'tr'), classifiedTitle(item, 'tr'));
        if (classifiedTitle(detail, 'tr').isEmpty) untitled++;
        details++;
      }
      final title = classifiedTitle(
        list.records.firstWhere(
          (item) => classifiedTitle(item, 'tr').isNotEmpty,
        ),
        'tr',
      );
      await tapUI(tester, find.text(title));
      await pumpUI(tester);
      final remote = tester.state<RemoteContentState>(
        find.byType(RemoteContent),
      );
      await loaded(tester, () => remote.data != null || remote.error != null);
      expect(remote.error, isNull);
      expect(find.text(title), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(
        api.token,
        isNotNull,
        reason:
            'Use the existing simulator session; do not create or change an account.',
      );
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const NotificationsScreen()),
      );
      await tester.pump();
      final notifications = tester.state<RecordListState>(
        find.byType(RecordList),
      );
      await loaded(
        tester,
        () => notifications.loaded || notifications.error != null,
      );
      expect(notifications.error, isNull);
      for (final item in notifications.records) {
        expect(notificationText(item, 'tr'), isNotEmpty);
      }
      expect(tester.takeException(), isNull);
      debugPrint(
        'SECONDARY_SERVICE classified_details=$details untitled_legacy_records=$untitled notifications=${notifications.records.length} sender_records=${notifications.records.where((n) => notificationSender(n).isNotEmpty).length} writes=0',
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.dio.close();
    },
    skip: !const bool.fromEnvironment('SECONDARY_SERVICE'),
  );
}
