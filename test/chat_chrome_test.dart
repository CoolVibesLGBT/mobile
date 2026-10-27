import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/app_button.dart';
import 'package:coolvibes/components/app_header.dart';
import 'package:coolvibes/components/chat_input.dart';
import 'package:coolvibes/components/attachment_controls.dart';
import 'package:coolvibes/components/glass_surface.dart';
import 'package:coolvibes/components/message_field.dart';
import 'package:coolvibes/core/attachments.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/design/app_design.dart';
import 'package:coolvibes/screens/chat.dart';
import 'support/glass_assertions.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;

class VoiceAttachments extends AttachmentController {
  int starts = 0, stops = 0;
  bool cancelled = false;
  final permission = Completer<void>();
  @override
  Future<void> startRecording() async {
    starts++;
    await permission.future;
    recording = true;
    changed();
  }

  @override
  Future<void> stopRecording({bool cancel = false}) async {
    stops++;
    recording = false;
    cancelled = cancel;
    if (!cancel) {
      files.add({
        'path': '/tmp/test-voice.m4a',
        'mime': 'audio/mp4',
        'duration': 2,
      });
    }
    changed();
  }
}

void main() {
  testWidgets(
    'input pressure stretches and springs back without claiming editing gestures',
    (tester) async {
      final controller = TextEditingController(text: 'Merhaba dünya');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: MessageField(
                  controller: controller,
                  focusNode: focus,
                  placeholder: 'Message',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectInputGlassPress(tester);
      final editor = find.byType(TextField);
      await tester.tap(editor);
      await tester.enterText(editor, 'Merhaba dünya');
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      await tester.longPressAt(
        tester.getTopLeft(editor) + const Offset(35, 22),
      );
      await tester.pumpAndSettle();
      expect(controller.selection.isCollapsed, isFalse);
      expect(controller.text, 'Merhaba dünya');
      expect(
        find.ancestor(
          of: editor,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.button == true,
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'chat header and composer share frost and shadow in $brightness',
      (tester) async {
        final session = Session(
          PreviewApi(PreviewState.populated),
          persistPreferences: false,
        )..ready = true;
        addTearDown(session.dispose);
        await tester.pumpWidget(
          CoolvibesApp(
            session: session,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Theme(
                        data: AppDesign.theme(brightness),
                        child: ChatScreen(chat: previewChat),
                      ),
                    ),
                  ),
                  child: const Text('Open chat'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open chat'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expectChatMaterials(tester);
        final back = find
            .descendant(
              of: find.byType(AppHeader),
              matching: find.byType(AppIconButton),
            )
            .first;
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(ChatScreen), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('neutral surfaces and buttons share material in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesign.theme(brightness),
          home: Scaffold(
            body: Column(
              children: [
                const GlassSurface(child: SizedBox(width: 180, height: 44)),
                AppIconButton(icon: const Icon(Icons.add), onPressed: () {}),
                AppIconButton(
                  icon: const Icon(Icons.arrow_upward),
                  prominent: true,
                  color: Colors.black,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.widget<liquid.GlassContainer>(
        find.byType(liquid.GlassContainer),
      );
      final buttons = tester
          .widgetList<liquid.GlassButton>(find.byType(liquid.GlassButton))
          .toList();
      expect(buttons.first.settings, surface.settings);
      expect(buttons.first.quality, surface.quality);
      // A custom accent is not multiplied by the vendor prominent preset.
      expect(buttons.last.style, liquid.GlassButtonStyle.filled);
      expect(buttons.last.settings!.bodyMode, liquid.GlassBodyMode.clear);
      final glyph = find
          .descendant(
            of: find.byType(AppIconButton).last,
            matching: find.byType(Icon),
          )
          .first;
      expect(IconTheme.of(tester.element(glyph)).color, Colors.black);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('input uses optical frost while sheets retain their white blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const GlassSurface(
                role: GlassSurfaceRole.input,
                child: SizedBox(width: 200, height: 44),
              ),
              const GlassSurface(
                role: GlassSurfaceRole.sheet,
                child: SizedBox(width: 300, height: 300),
              ),
              AppIconButton(icon: const Icon(Icons.add), onPressed: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surfaces = tester
        .widgetList<liquid.GlassContainer>(find.byType(liquid.GlassContainer))
        .toList();
    for (final surface in surfaces) {
      expect(surface.settings!.glassColor.r, 1);
      expect(surface.settings!.glassColor.g, 1);
      expect(surface.settings!.glassColor.b, 1);
    }
    final input = surfaces.first;
    expect(input.quality, liquid.GlassQuality.premium);
    expect(input.settings!.glassColor, AppDesign.glassInputLight);
    expect(input.settings!.blur, AppDesign.glassSurfaceBlur);
    expect(input.settings!.standardOpacityMultiplier, 1);
    expect(input.settings!.thickness, greaterThan(0));
    expect(input.settings!.lightIntensity, greaterThan(0));
    expect(input.settings!.fresnelStrength, greaterThan(0));
    final sheet = surfaces.last;
    expect(sheet.quality, liquid.GlassQuality.minimal);
    expect(sheet.settings!.glassColor, AppDesign.glassSheetLight);
    expect(sheet.settings!.blur, AppDesign.glassSurfaceBlur);
    expect(find.byType(BackdropFilter), findsWidgets);
    final button = tester.widget<liquid.GlassButton>(
      find.byType(liquid.GlassButton),
    );
    expect(button.quality, liquid.GlassQuality.premium);
    expect(button.settings!.glassColor.a, lessThan(.2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessible input keeps editing and uses the frosted fallback', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            highContrast: true,
            disableAnimations: true,
          ),
          child: Scaffold(
            body: Center(
              child: MessageField(
                controller: controller,
                focusNode: focus,
                placeholder: 'Message',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byType(MessageField);
    expect(
      find.descendant(of: input, matching: find.byType(BackdropFilter)),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: input,
        matching: find.byType(liquid.LiquidGlassLayer),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: input,
        matching: find.byType(liquid.LightweightLiquidGlass),
      ),
      findsNothing,
    );
    final glow = tester.widget<liquid.GlassGlow>(
      find.descendant(of: input, matching: find.byType(liquid.GlassGlow)),
    );
    expect(glow.enabled, isFalse);
    final surface = find.descendant(
      of: input,
      matching: find.byType(liquid.GlassContainer),
    );
    final rest = tester.getRect(surface);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TextField)),
    );
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getRect(surface), rest);
    await gesture.cancel();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Merhaba 👋');
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(controller.text, 'Merhaba 👋');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> composer(
    WidgetTester tester,
    TextEditingController text,
    AttachmentController attachments, {
    VoidCallback? onSend,
    bool sending = false,
    bool rtl = false,
  }) async {
    final session = Session(
      PreviewApi(PreviewState.populated),
      persistPreferences: false,
    )..ready = true;
    addTearDown(session.dispose);
    await tester.pumpWidget(
      CoolvibesApp(
        session: session,
        home: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.green)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ChatInput(
                    controller: text,
                    attachments: attachments,
                    sending: sending,
                    onSend: onSend ?? () {},
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Busy state intentionally has a continuously animating progress indicator.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'send moves inside the expanded field and keeps its leading edge',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final text = TextEditingController();
      final attachments = AttachmentController();
      addTearDown(text.dispose);
      addTearDown(attachments.dispose);
      var sends = 0;
      await composer(tester, text, attachments, onSend: () => sends++);
      final field = find.byType(MessageField);
      final idle = tester.getRect(field);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is AppIconButton &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.mic_none,
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Merhaba');
      await tester.pumpAndSettle();
      expect(tester.getRect(field).left, idle.left);
      expect(
        tester.getRect(field).width,
        idle.width + AppDesign.composerControl + AppDesign.composerGap,
      );
      final send = find.byWidgetPredicate(
        (w) => w is AppIconButton && w.prominent,
      );
      expect(tester.getRect(field).contains(tester.getCenter(send)), isTrue);
      expect(tester.widget<AppIconButton>(send).embedded, isTrue);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(sends, 1);
      // Full footer is transparent: only the editor and controls own glass.
      expect(
        find.ancestor(
          of: find.byType(ChatInput),
          matching: find.byType(GlassSurface),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mic permission wait cannot start twice and stop stays reachable',
    (tester) async {
      final text = TextEditingController();
      final attachments = VoiceAttachments();
      addTearDown(text.dispose);
      addTearDown(attachments.dispose);
      await composer(tester, text, attachments);
      final mic = find.byWidgetPredicate(
        (w) =>
            w is AppIconButton &&
            w.icon is Icon &&
            (w.icon as Icon).icon == Icons.mic_none,
      );
      final position = tester.getCenter(mic);
      await tester.tapAt(position);
      await tester.pump();
      await tester.tapAt(position);
      await tester.pump();
      expect(attachments.starts, 1);
      attachments.permission.complete();
      await tester.pumpAndSettle();
      expect(attachments.recording, isTrue);
      expect(find.byType(VoiceRecordingBar), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      final stop = find
          .byWidgetPredicate(
            (w) =>
                w is AppIconButton &&
                w.icon is Icon &&
                (w.icon as Icon).icon == Icons.stop,
          )
          .last;
      await tester.tap(stop);
      await tester.pumpAndSettle();
      expect(attachments.stops, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('holding then releasing sends one voice message', (tester) async {
    final text = TextEditingController();
    final attachments = VoiceAttachments()..permission.complete();
    addTearDown(text.dispose);
    addTearDown(attachments.dispose);
    var sends = 0;
    await composer(tester, text, attachments, onSend: () => sends++);
    final mic = find.byWidgetPredicate(
      (w) => w is AppIconButton && w.onLongPressStart != null,
    );
    final hold = await tester.startGesture(tester.getCenter(mic));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(attachments.recording, isTrue);
    await hold.up();
    await tester.pumpAndSettle();
    expect(attachments.stops, 1);
    expect(sends, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'slide cancel during permission wait discards instead of sending',
    (tester) async {
      final text = TextEditingController();
      final attachments = VoiceAttachments();
      addTearDown(text.dispose);
      addTearDown(attachments.dispose);
      var sends = 0;
      await composer(tester, text, attachments, onSend: () => sends++);
      final mic = find.byWidgetPredicate(
        (w) => w is AppIconButton && w.onLongPressStart != null,
      );
      final hold = await tester.startGesture(tester.getCenter(mic));
      await tester.pump(const Duration(milliseconds: 600));
      await hold.moveBy(const Offset(-100, 0));
      await tester.pump();
      attachments.permission.complete();
      await tester.pumpAndSettle();
      await hold.up();
      await tester.pumpAndSettle();
      expect(attachments.cancelled, isTrue);
      expect(attachments.files, isEmpty);
      expect(sends, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('slide up locks recording, explicit send stops and sends once', (
    tester,
  ) async {
    final text = TextEditingController();
    final attachments = VoiceAttachments()..permission.complete();
    addTearDown(text.dispose);
    addTearDown(attachments.dispose);
    var sends = 0;
    await composer(tester, text, attachments, onSend: () => sends++);
    final mic = find.byWidgetPredicate(
      (w) => w is AppIconButton && w.onLongPressStart != null,
    );
    final hold = await tester.startGesture(tester.getCenter(mic));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await hold.moveBy(const Offset(0, -80));
    await tester.pump();
    await hold.up();
    await tester.pumpAndSettle();
    expect(attachments.recording, isTrue);
    expect(sends, 0);
    await tester.tap(
      find.byWidgetPredicate((w) => w is AppIconButton && w.prominent),
    );
    await tester.pumpAndSettle();
    expect(attachments.stops, 1);
    expect(sends, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL multiline editor remains above keyboard while sending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 310);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final text = TextEditingController(text: 'مرحبا\nSecond line');
    final attachments = AttachmentController();
    addTearDown(text.dispose);
    addTearDown(attachments.dispose);
    await composer(tester, text, attachments, sending: true, rtl: true);
    final field = tester.getRect(find.byType(MessageField));
    expect(field.bottom, lessThanOrEqualTo(812 - 310 - 6));
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(tester.takeException(), isNull);
  });
}
