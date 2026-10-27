import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/attachment_sheet.dart';
import 'header_profile_edit_test.dart' as fixture;
import 'support/ui_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.fluttercandies/photo_manager');
  final requests = <MethodCall>[];
  Completer<String>? download;
  setUp(() {
    requests.clear();
    download = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          requests.add(call);
          return switch (call.method) {
            'requestPermissionExtend' => 3,
            'getAssetPathList' => {
              'data': [
                {
                  'id': 'recents',
                  'name': 'Recents',
                  'assetCount': 1,
                  'isAll': true,
                },
              ],
            },
            'getAssetListPaged' => {
              'data': [
                {
                  'id': 'photo',
                  'type': 1,
                  'width': 900,
                  'height': 300,
                  'title': 'photo.jpg',
                },
              ],
            },
            'getThumbnail' => null,
            'getFullFile' =>
              download == null ? '/fixture/photo.jpg' : await download!.future,
            'getTitleAsync' => 'photo.jpg',
            _ => null,
          };
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  for (final single in [true, false]) {
    testWidgets(
      'gallery ${single ? 'opens one photo directly' : 'retains chat selection until send'}',
      (tester) async {
        final picked = <AttachmentPick>[];
        final session = await fixture.mount(
          tester,
          Builder(
            builder: (context) => AppScaffold(
              body: Center(
                child: AppButton(
                  child: const Text('Open photos'),
                  onPressed: () => showAttachmentSheet(
                    context,
                    singlePhoto: single,
                    title: 'Profile photo',
                    sendLabel: 'Use selected',
                    onCamera: () {},
                    onLibrary: () {},
                    actions: const [],
                    onSelect: (items) async {
                      picked.addAll(items);
                      return true;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await fixture.visibleTap(tester, find.text('Open photos'));
        final tile = find.byKey(const ValueKey('photo'));
        expect(tile, findsOneWidget);
        final albumRequest = requests.firstWhere(
          (c) => c.method == 'getAssetPathList',
        );
        expect((albumRequest.arguments as Map)['type'], single ? 1 : 3);
        await tester.tap(tile);
        await pumpUI(tester);
        if (!single) {
          expect(picked, isEmpty);
          expect(find.byKey(const ValueKey('media.library')), findsOneWidget);
          await fixture.visibleTap(tester, find.text('Use selected'));
        }
        expect(picked, hasLength(1));
        expect(picked.single.path, '/fixture/photo.jpg');
        final fileRequest = requests.firstWhere(
          (c) => c.method == 'getFullFile',
        );
        expect((fileRequest.arguments as Map)['isOrigin'], !single);
        expect(find.byKey(const ValueKey('media.library')), findsNothing);
        await fixture.finish(tester, session);
      },
    );
  }

  testWidgets('dismissing while a cloud photo loads does not select it later', (
    tester,
  ) async {
    download = Completer<String>();
    var selections = 0;
    final session = await fixture.mount(
      tester,
      Builder(
        builder: (context) => AppScaffold(
          body: Center(
            child: AppButton(
              child: const Text('Open photos'),
              onPressed: () => showAttachmentSheet(
                context,
                singlePhoto: true,
                sendLabel: 'Use selected',
                onCamera: () {},
                onLibrary: () {},
                actions: const [],
                onSelect: (_) async {
                  selections++;
                  return true;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await fixture.visibleTap(tester, find.text('Open photos'));
    await tester.tap(find.byKey(const ValueKey('photo')));
    await pumpUI(tester);
    Navigator.of(
      tester.element(find.byKey(const ValueKey('media.library'))),
    ).pop();
    await pumpUI(tester);
    download!.complete('/fixture/photo.jpg');
    await pumpUI(tester);
    expect(selections, 0);
    await fixture.finish(tester, session);
  });
}
