import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/article_content.dart';
import 'package:coolvibes/components/record_list.dart';
import 'package:coolvibes/components/remote_content.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/localized_content.dart';
import 'package:coolvibes/core/place_data.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/screens/places.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/support/ui_driver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  testWidgets(
    'public service places resolve every requested detail and render fallback Lexical',
    (tester) async {
      await liquid.LiquidGlassWidgets.initialize(
        enablePerformanceMonitor: false,
      );
      final api = Api();
      final session = Session(api, persistPreferences: false)..ready = true;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const PlacesScreen()),
      );
      await tester.pump();
      final list = tester.state<RecordListState>(find.byType(RecordList));
      for (var i = 0; i < 100 && !list.loaded && list.error == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(list.error, isNull);
      expect(list.records, isNotEmpty);
      var checked = 0, fallbacks = 0;
      for (final record in list.records.take(30)) {
        final response = await api.call(
          'post.fetch',
          body: {'post_id': recordId(record)},
        );
        final detail = placeFromResponse(response, recordId(record));
        expect(
          detail,
          isNotNull,
          reason: 'Service must return the requested place',
        );
        expect(placeTitle(detail!, 'tr'), isNotEmpty);
        expect(placeTitle(detail, 'tr'), placeTitle(record, 'tr'));
        final raw = object(decodeContent(detail['content']));
        if (!contentIsPresent(raw['tr']) && contentIsPresent(raw)) {
          fallbacks++;
          expect(contentIsPresent(placeContent(detail, 'tr')), isTrue);
        }
        checked++;
      }
      final target = list.records.length > 1
          ? list.records[1]
          : list.records.first;
      await tapUI(tester, find.byKey(ValueKey('place.${recordId(target)}')));
      await pumpUI(tester);
      final remote = tester.state<RemoteContentState>(
        find.byType(RemoteContent),
      );
      for (
        var i = 0;
        i < 100 && remote.data == null && remote.error == null;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(remote.error, isNull);
      expect(remote.data, isNotNull);
      expect(find.text(placeTitle(target, 'tr')), findsWidgets);
      expect(find.byType(ArticleContent), findsOneWidget);
      debugPrint(
        'PLACES_SERVICE details=$checked fallbacks=$fallbacks opened_requested_id=true',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.dio.close();
    },
    skip: !const bool.fromEnvironment('PLACES_SERVICE'),
  );
}
