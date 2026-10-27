import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/components/chat_list_row.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:coolvibes/core/api.dart';
import 'package:dio/dio.dart';
import 'package:coolvibes/components/components.dart';
import 'support/ui_driver.dart';
import 'package:flutter/foundation.dart';

class MultiForwardApi extends PreviewApi {
  MultiForwardApi() : super(PreviewState.populated);
  final requests = <Json>[];
  bool rejectGroup = false;
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (action == 'chat.forward_messages') {
      requests.add(Map.of(body));
      if (rejectGroup && body['chat_id'] == 'g1') {
        throw ApiException('Unavailable', 503);
      }
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
  for (final partialFailure in [false, true]) {
    testWidgets(
      'multiple recipients keep search selection and retry only failures: $partialFailure',
      (tester) async {
        final api = MultiForwardApi()..rejectGroup = partialFailure;
        final session = Session(api, persistPreferences: false)
          ..ready = true
          ..user = previewSelf;
        ForwardResult? result;
        await tester.pumpWidget(
          CoolvibesApp(
            session: session,
            home: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    result = await sheet<ForwardResult>(
                      context,
                      const ForwardScreen(
                        draft: ChatForward(
                          sourceChatId: 'source',
                          messages: [
                            {'id': 'm1'},
                            {'id': 'm2'},
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          session.dispose();
        });
        await tester.tap(find.text('open'));
        await pumpUI(tester);
        await tester.tap(find.byKey(const ValueKey('forward.select')));
        await pumpUI(tester);
        await tester.tap(find.byType(ChatListRow).first);
        await pumpUI(tester);
        final search = find.descendant(
          of: find.byType(AppSearchField),
          matching: find.byType(EditableText),
        );
        await tester.enterText(search, 'İstanbul');
        await pumpUI(tester);
        expect(find.byType(ChatListRow), findsOneWidget);
        await tester.tap(find.byType(ChatListRow).first);
        await pumpUI(tester);
        await tester.enterText(search, '');
        await pumpUI(tester);
        expect(
          tester
              .widgetList<ChatListRow>(find.byType(ChatListRow))
              .where((r) => r.selected == true)
              .length,
          2,
        );
        final comment = find.descendant(
          of: find.byKey(const ValueKey('forward.comment')),
          matching: find.byType(TextField),
        );
        await tester.enterText(comment, 'For both chats');
        await pumpUI(tester);
        final send = find.byKey(const ValueKey('forward.send'));
        await tester.ensureVisible(send);
        await tester.tap(send);
        await pumpUI(tester);
        expect(api.requests.length, 2);
        expect(api.requests.map((r) => r['chat_id']), ['c1', 'g1']);
        for (final request in api.requests) {
          expect(request['source_chat_id'], 'source');
          expect(request['message_ids[]'], ['m1', 'm2']);
          expect(request['content'], 'For both chats');
        }
        if (partialFailure) {
          expect(result, isNull);
          expect(find.byType(ForwardScreen), findsOneWidget);
          expect(
            tester.widget<ChatListRow>(find.byType(ChatListRow)).selected,
            isTrue,
          );
          expect(
            tester.widget<TextField>(comment).controller!.text,
            'For both chats',
          );
          api.rejectGroup = false;
          await tester.tap(send);
          await pumpUI(tester);
          expect(api.requests.map((r) => r['chat_id']), ['c1', 'g1', 'g1']);
        }
        expect(find.byType(ForwardScreen), findsNothing);
        expect(result!.sentCount, 2);
        expect(result!.chat, isNull);
        expect(result!.messages.map((m) => m['chat_id']).toSet(), {'c1', 'g1'});
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('forward picker shows chat rows and returns the tapped chat', (
    tester,
  ) async {
    final session =
        Session(PreviewApi(PreviewState.populated), persistPreferences: false)
          ..ready = true
          ..user = previewSelf;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  sheet<ForwardResult>(context, const ForwardScreen()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final rows = find.byType(ChatListRow);
    expect(rows, findsWidgets);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    // At the full detent the sheet must still blur the page behind it.
    final sheetRoot = find.byType(liquid.GlassModalSheetScaffold);
    final backdrops = find.descendant(
      of: sheetRoot,
      matching: find.byType(BackdropFilter),
    );
    expect(
      backdrops.evaluate().any((element) {
        final size = tester.getSize(find.byWidget(element.widget));
        return size.width > screen.width * .9 &&
            size.height > screen.height * .7;
      }),
      isTrue,
    );
    final modalFill = tester.widget<DecoratedBox>(
      find.byKey(const Key('glass_modal_sheet_fill')),
    );
    expect((modalFill.decoration as BoxDecoration).color!.a, 0);
    final pageBackground = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppScaffold),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((pageBackground.decoration as BoxDecoration).color!.a, 0);
    final avatar = tester.getRect(find.byType(Avatar).first);
    expect(avatar.left, greaterThanOrEqualTo(0));
    expect(avatar.right, lessThanOrEqualTo(screen.width));
    // Tapping a chat returns it to the caller (PeerSelectionController).
    await tester.tap(rows.first);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ForwardScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
