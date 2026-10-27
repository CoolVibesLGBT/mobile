import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/chat_list_row.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/components/record_list.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/chat.dart';
import 'support/ui_driver.dart';

class PendingChatsApi extends PreviewApi {
  PendingChatsApi() : super(PreviewState.populated);
  Completer<Json>? refresh;
  final requests = <String>[];

  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) {
    requests.add(action);
    if (action == 'chat.set_muted') return Future.value({'success': true});
    return action == 'chat.fetch_chats' && refresh != null
        ? refresh!.future
        : super.call(
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
    'chat preview springs from the row, centers actions and opens the conversation',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
      tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
      addTearDown(tester.view.reset);
      final api = PendingChatsApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const ChatsScreen()),
      );
      await pumpUI(tester);
      final row = find.byType(ChatListRow).first;
      final press = await tester.startGesture(tester.getCenter(row));
      await tester.pump(const Duration(milliseconds: 330));
      await tester.pump(const Duration(milliseconds: 16));
      final transform = find.byKey(const ValueKey('context.preview.transform'));
      final opening = tester.widget<Transform>(transform).transform.storage[0];
      expect(opening, lessThan(.3));
      await press.up();
      await pumpUI(tester);
      expect(
        tester.widget<Transform>(transform).transform.storage[0],
        closeTo(1, .01),
      );
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).preview,
        isTrue,
      );
      expect(api.requests.where((a) => a == 'chat.message_read'), isEmpty);
      final surface = find.byKey(const ValueKey('context.actions.surface'));
      final glass = tester.widget<GlassSurface>(surface);
      expect(glass.role, GlassSurfaceRole.menu);
      expect(
        appGlassSettings(
          tester.element(surface),
          role: glass.role,
        ).glassColor.a,
        closeTo(.7, .01),
      );
      expect(glass.useOwnLayer, isTrue);
      final previewRect = tester.getRect(find.byType(ChatScreen));
      final menuRect = tester.getRect(surface);
      expect(previewRect.left, closeTo(12, .1));
      expect(previewRect.height, closeTo(460, 1));
      expect(menuRect.top - previewRect.bottom, closeTo(10, 1));
      for (final action in [
        ('Sabitle', 'chat.action.pin'),
        ('Sessize al', 'chat.action.mute'),
        ('Sil', 'chat.action.delete'),
      ]) {
        final label = find.descendant(
          of: surface,
          matching: find.text(action.$1),
        );
        final icon = find.descendant(
          of: surface,
          matching: find.byWidgetPredicate(
            (w) => w is AppSymbol && w.name == action.$2,
          ),
        );
        final hitTarget = find
            .ancestor(of: label, matching: find.byType(GestureDetector))
            .first;
        expect(tester.getSize(hitTarget).height, 44);
        expect(
          tester.getCenter(label).dy,
          closeTo(tester.getCenter(hitTarget).dy, .1),
        );
        expect(
          tester.getCenter(icon).dy,
          closeTo(tester.getCenter(hitTarget).dy, .1),
        );
      }
      Navigator.of(tester.element(find.byType(ChatScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Transform>(transform).transform.storage[0],
        lessThan(.8),
      );
      await pumpUI(tester);
      expect(find.byType(ChatScreen), findsNothing);
      final mutePress = await tester.startGesture(tester.getCenter(row));
      await pumpUI(tester);
      await mutePress.up();
      await pumpUI(tester);
      expect(surface, findsOneWidget);
      await tester.tap(
        find.descendant(of: surface, matching: find.text('Sessize al')),
      );
      await pumpUI(tester);
      expect(api.requests.where((a) => a == 'chat.set_muted').length, 1);
      expect(tester.widget<ChatListRow>(row).muted, isTrue);
      final openPress = await tester.startGesture(tester.getCenter(row));
      await pumpUI(tester);
      await openPress.up();
      await pumpUI(tester);
      await tester.tap(
        find
            .ancestor(of: transform, matching: find.byType(GestureDetector))
            .first,
      );
      await pumpUI(tester);
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).preview,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('context.actions.surface')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  for (final rtl in [false, true]) {
    testWidgets(
      'closed swipe actions never bleed through a pressed row: $rtl',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final session =
            Session(PreviewApi(PreviewState.empty), persistPreferences: false)
              ..ready = true
              ..user = previewSelf
              ..locale = Locale(rtl ? 'ar' : 'tr');
        final boundaryKey = GlobalKey();
        var muted = 0;
        await tester.pumpWidget(
          CoolvibesApp(
            session: session,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: ChatListRow(
                    avatar: previewPeer,
                    name: 'Ege',
                    preview: 'Merhaba',
                    time: '02:03',
                    unread: 0,
                    onTap: () {},
                    onMute: () => muted++,
                    onDelete: () {},
                    onPin: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await pumpUI(tester);
        final row = find.byType(ChatListRow);
        Future<int> actionPixels() async => (await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var count = 0;
          for (var y = 0; y < image.height; y++) {
            final start = rtl ? 0 : image.width - 148;
            for (var x = start; x < start + 148; x++) {
              final i = (y * image.width + x) * 4;
              if (data.getUint8(i) > 240 &&
                  data.getUint8(i + 1) < 170 &&
                  data.getUint8(i + 2) < 90) {
                count++;
              }
            }
          }
          image.dispose();
          return count;
        }))!;

        expect(await actionPixels(), 0);
        final press = await tester.startGesture(tester.getCenter(row));
        await tester.pump(const Duration(milliseconds: 130));
        await tester.pump(const Duration(milliseconds: 100));
        expect(await actionPixels(), 0);
        await press.cancel();
        await pumpUI(tester);
        expect(await actionPixels(), 0);
        await tester.drag(row, Offset(rtl ? 160 : -160, 0));
        await pumpUI(tester);
        expect(await actionPixels(), greaterThan(8000));
        final rect = tester.getRect(row);
        await tester.tapAt(
          Offset(rtl ? rect.left + 111 : rect.right - 111, rect.center.dy),
        );
        await pumpUI(tester);
        expect(muted, 1);
        expect(await actionPixels(), 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }

  testWidgets(
    'chat return preserves rows until refresh succeeds and on failure',
    (tester) async {
      final api = PendingChatsApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const ChatsScreen()),
      );
      await pumpUI(tester);
      final first = find.byType(ChatListRow).first;
      final element = tester.element(first);
      final list = tester.state<RecordListState>(find.byType(RecordList));
      final offset = list.scroll.offset;
      await tester.tap(first);
      await pumpUI(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
      api.refresh = Completer<Json>();
      Navigator.of(tester.element(find.byType(ChatScreen))).pop();
      await pumpUI(tester);
      expect(find.byType(ChatScreen), findsNothing);
      expect(list.loading, isTrue);
      expect(find.byType(ChatListRow), findsNWidgets(2));
      expect(tester.element(first), same(element));
      expect(list.scroll.offset, offset);
      api.refresh!.complete({
        'data': [
          {
            ...previewChat,
            'last_message': {'content': 'Yeni mesaj'},
          },
        ],
      });
      await pumpUI(tester);
      expect(find.byType(ChatListRow), findsOneWidget);
      expect(tester.element(first), same(element));
      expect(find.text('Yeni mesaj'), findsOneWidget);
      api.refresh = Completer<Json>();
      unawaited(list.reload());
      await tester.pump();
      expect(find.text('Yeni mesaj'), findsOneWidget);
      api.refresh!.completeError(ApiException('Bağlantı kesildi'));
      await pumpUI(tester);
      expect(find.text('Yeni mesaj'), findsOneWidget);
      expect(list.error, contains('Bağlantı kesildi'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
