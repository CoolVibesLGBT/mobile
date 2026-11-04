import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/game_map.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/screens/feed.dart';

import 'support/ui_driver.dart';

class CheckInSearchApi extends PreviewApi {
  CheckInSearchApi() : super(PreviewState.populated);
  final requests = <Json>[];
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (action == 'user.check_in_fetch') {
      requests.add({...body});
      final term = string(body['search']);
      return page(term);
    }
    return super.call(action, body: body, get: get, cancelToken: cancelToken);
  }

  Json page(String term) => {
    'data': {
      'posts': [
        {
          ...previewPost,
          'id': 'checkin-$term',
          'public_id': 'checkin-$term',
          'post_kind': 'checkin',
          'location': {'latitude': 41.0, 'longitude': 29.0},
          'content': term.isEmpty ? 'Initial activity' : term,
        },
      ],
      'cursor': {'next': null},
    },
  };
}

void main() {
  testWidgets('check-in header opens the shared search screen', (tester) async {
    final api = CheckInSearchApi();
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const CheckInsScreen()),
    );
    await pumpUI(tester);
    expect(find.byType(GameMap), findsNothing);
    expect(api.requests.single.containsKey('latitude'), isFalse);
    expect(find.byType(AppSearchField), findsNothing);
    await tester.tap(find.byKey(const ValueKey('checkins.search')));
    await pumpUI(tester);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byType(AppSearchField), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('check-in map opens the selected post', (tester) async {
    final api = CheckInSearchApi();
    final session = Session(api, persistPreferences: false)
      ..ready = true
      ..user = previewSelf;
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const CheckInsScreen()),
    );
    await pumpUI(tester);
    tester
        .widget<AppIconButton>(find.byKey(const ValueKey('checkins.view')))
        .onPressed!();
    await pumpUI(tester);
    expect(api.requests.last.containsKey('search'), isFalse);
    final map = tester.widget<GameMap>(find.byType(GameMap));
    expect(map.markers.single['id'], 'checkin-');
    map.onMarker!('checkin-');
    await pumpUI(tester);
    expect(
      tester.widget<PostDetailScreen>(find.byType(PostDetailScreen)).post['id'],
      'checkin-',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
