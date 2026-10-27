import 'dart:async';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'audit_regression_test.dart' show AuditApi, AuditSession, press;
import 'package:coolvibes/l10n/l10n.dart';
import 'support/ui_driver.dart';

class SearchApi extends AuditApi {
  final requests = <Completer<Json>>[];
  final queries = <Json>[];
  final cancellations = <CancelToken?>[];
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) {
    if (action == 'search.global') {
      final request = Completer<Json>();
      requests.add(request);
      queries.add({...body});
      cancellations.add(cancelToken);
      return request.future;
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

void main() {
  testWidgets(
    'new query invalidates responses before debounce and clear cancels',
    (tester) async {
      final api = SearchApi();
      final session = AuditSession(api)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const SearchScreen()),
      );
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'old');
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.requests.length, 1);
      await tester.enterText(find.byType(EditableText), 'new');
      expect(api.cancellations.first!.isCancelled, isTrue);
      api.requests.first.complete({
        'data': {
          'users': [
            {'public_id': 41, 'displayname': 'Stale result'},
          ],
        },
      });
      await tester.pump();
      expect(find.text('Stale result'), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.requests.length, 2);
      api.requests.last.complete({
        'data': {
          'users': [
            {'public_id': 42, 'displayname': 'Current result'},
          ],
        },
      });
      await tester.pump();
      expect(find.text('Current result'), findsOneWidget);
      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
      await tester.pump();
      expect(find.text('Current result'), findsNothing);
      expect(api.cancellations.last!.isCancelled, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'search submit, repeated query, retry and scope stay functional',
    (tester) async {
      final api = SearchApi();
      final session = AuditSession(api)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const SearchScreen()),
      );
      await pumpUI(tester);
      final field = find.byType(EditableText);
      await tester.enterText(field, 'original');
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.requests, hasLength(1));
      await tester.enterText(field, 'replacement');
      await tester.enterText(field, 'original');
      expect(api.cancellations.first!.isCancelled, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(api.requests, hasLength(2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        api.requests,
        hasLength(2),
        reason: 'Submitting cancels the debounce.',
      );
      api.requests.first.complete({'data': {}});
      api.requests.last.completeError(StateError('Connection failed'));
      await pumpUI(tester);
      final l = tester.element(find.byType(SearchScreen)).l10n;
      await tester.tap(press(l.tryAgain));
      await tester.pump();
      expect(api.requests, hasLength(3));
      expect(api.queries.last['query'], 'original');
      api.requests.last.complete({
        'data': {
          'users': [
            {'public_id': 42, 'displayname': 'Recovered result'},
          ],
        },
      });
      await pumpUI(tester);
      expect(find.text('Recovered result'), findsOneWidget);
      await tester.tap(find.text(l.people));
      await tester.pump();
      expect(api.requests, hasLength(4));
      expect(api.queries.last['scope'], 'people');
      api.requests.last.complete({'data': {}});
      await pumpUI(tester);
      expect(find.text(l.noResults), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets(
    'floating search input responds to press and stays above keyboard',
    (tester) async {
      final session = AuditSession(SearchApi())
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const SearchScreen()),
      );
      await pumpUI(tester);
      final search = find.byType(AppSearchField);
      final surface = find.descendant(
        of: search,
        matching: find.byType(GlassSurface),
      );
      final bounds = tester.getRect(surface);
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final keyboard =
          tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
      expect(bounds.bottom, lessThanOrEqualTo(height - keyboard));
      final list = find.descendant(
        of: find.byType(SearchScreen),
        matching: find.byType(ListView),
      );
      expect(
        tester.getRect(list).bottom,
        greaterThan(bounds.top),
        reason: 'Results must scroll behind the floating glass field.',
      );
      final gesture = await tester.startGesture(tester.getCenter(surface));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getRect(surface).width, greaterThan(bounds.width));
      await gesture.up();
      await pumpUI(tester);
      expect(tester.getRect(surface).width, closeTo(bounds.width, 1));
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
