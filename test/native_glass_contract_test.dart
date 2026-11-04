import 'package:coolvibes/components/app_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'iOS glass keeps gestures in Flutter and updates native material',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final created = <Map<Object?, Object?>>[];
      final updates = <Map<Object?, Object?>>[];
      final channels = <MethodChannel>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async {
          if (call.method == 'create') {
            final args = call.arguments as Map<Object?, Object?>;
            created.add(args);
            final channel = MethodChannel('coolvibes/glass_${args['id']}');
            channels.add(channel);
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              (update) async {
                updates.add(update.arguments as Map<Object?, Object?>);
                return null;
              },
            );
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
        for (final channel in channels) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        }
      });
      var taps = 0;
      Future<void> build(Brightness brightness) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Center(
            child: AppButton(
              onPressed: () => taps++,
              child: const Text('Continue'),
            ),
          ),
        ),
      );
      await build(Brightness.light);
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      expect(created.single['viewType'], 'coolvibes/glass');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      await build(Brightness.dark);
      await tester.pumpAndSettle();
      expect(created, hasLength(1));
      expect(updates.last['dark'], isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('compact icons keep an accessible target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AppIconButton(
            dimension: 28,
            glass: false,
            tooltip: 'Add',
            icon: const Icon(Icons.add),
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppIconButton)), const Size(44, 44));
    final bounds = tester.getRect(find.byType(AppIconButton));
    await tester.tapAt(bounds.topLeft + const Offset(2, 22));
    expect(taps, 1);
  });

  testWidgets('glass title scales once with Dynamic Type', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: SizedBox(
              width: 300,
              height: 60,
              child: GlassButton(
                title: 'Continue',
                label: 'Continue',
                color: Colors.black,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.text('Continue'),
        matching: find.byType(RichText),
      ),
    );
    expect(richText.text.style!.fontSize, 17);
    expect(richText.textScaler.scale(17), 34);
    expect(tester.takeException(), isNull);
  });
}
