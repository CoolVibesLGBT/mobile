import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/profile_photo_editor.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'package:coolvibes/screens/app_forms.dart';
import 'header_profile_edit_test.dart' as fixture;
import 'support/profile_api.dart';
import 'support/ui_driver.dart';

class PhotoApi extends ProfileApi {
  bool fail = false;
  final uploads = <({String kind, Uint8List bytes})>[];
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (!action.startsWith('user.upload_')) {
      return super.call(
        action,
        body: body,
        get: get,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        receiveTimeout: receiveTimeout,
      );
    }
    final kind = action.split('_').last;
    final file = body[kind] as MultipartFile;
    expect(file.contentType.toString(), 'image/png');
    expect(file.filename, '$kind.png');
    uploads.add((
      kind: kind,
      bytes: await file
          .finalize()
          .fold<BytesBuilder>(
            BytesBuilder(),
            (buffer, chunk) => buffer..add(chunk),
          )
          .then((buffer) => buffer.takeBytes()),
    ));
    if (fail) throw ApiException('Fixture upload failure');
    return {
      'success': true,
      'data': {'user': self},
    };
  }
}

Future<Uint8List> fixtureImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var i = 0; i < 3; i++) {
    canvas.drawRect(
      Rect.fromLTWH(i * 300, 0, 300, 300),
      Paint()..color = [Colors.red, Colors.green, Colors.blue][i],
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(900, 300);
  picture.dispose();
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  image.dispose();
  return bytes;
}

Future<void> tapAsync(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await pumpUI(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.fluttercandies/photo_manager'),
          (call) async => call.method == 'requestPermissionExtend' ? 1 : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.fluttercandies/photo_manager'),
          null,
        );
  });
  for (final kind in ProfilePhotoKind.values) {
    testWidgets(
      '${kind.name}: cancel, crop preview, failure retention and exact upload dimensions',
      (tester) async {
        final api = PhotoApi();
        final bytes = await tester.runAsync(fixtureImage);
        XFile? chosen;
        final session = await fixture.mount(
          tester,
          ProfilePhotoEditor(kind: kind, picker: (_) async => chosen),
          api: api,
        );
        final l = tester.element(find.byType(ProfilePhotoEditor)).l10n;
        final save = find.widgetWithText(AppButton, l.save);
        expect(tester.widget<AppButton>(save).onPressed, isNull);
        await tapAsync(tester, find.text(l.chooseFromLibrary));
        expect(api.uploads, isEmpty);
        chosen = XFile.fromData(bytes!, name: 'fixture.png');
        await tapAsync(tester, find.text(l.chooseFromLibrary));
        final crop = find.byKey(const ValueKey('profile.photo.crop'));
        expect(crop, findsOneWidget);
        expect(
          api.uploads,
          isEmpty,
          reason: 'selection never uploads without confirmation',
        );
        final viewer = tester.widget<InteractiveViewer>(crop);
        final original = viewer.transformationController!.value.clone();
        if (kind == ProfilePhotoKind.avatar) {
          await tester.ensureVisible(crop);
          await pumpUI(tester);
          await tester.timedDrag(
            crop,
            const Offset(-80, 0),
            const Duration(milliseconds: 300),
          );
          await pumpUI(tester);
          expect(viewer.transformationController!.value, isNot(original));
          await tester.tap(find.text(l.reset));
          await pumpUI(tester);
          expect(viewer.transformationController!.value, original);
        }
        api.fail = true;
        await tapAsync(tester, save);
        expect(find.text(l.uploadStatusFailed), findsOneWidget);
        expect(crop, findsOneWidget);
        expect(tester.widget<AppButton>(save).onPressed, isNotNull);
        expect(api.uploads.single.kind, kind.name);
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
            api.uploads.single.bytes,
          );
          final image = (await codec.getNextFrame()).image;
          expect(
            image.width / image.height,
            kind == ProfilePhotoKind.avatar ? 1 : 3,
          );
          final pixels = (await image.toByteData())!.buffer.asUint8List();
          final expected = kind == ProfilePhotoKind.avatar
              ? Colors.green
              : Colors.red;
          final sample =
              ((image.height ~/ 2) * image.width + image.width ~/ 6) * 4;
          expect(pixels.sublist(sample, sample + 3), [
            (expected.r * 255).round(),
            (expected.g * 255).round(),
            (expected.b * 255).round(),
          ]);
          image.dispose();
          codec.dispose();
        });
        api.fail = false;
        await tapAsync(tester, save);
        expect(api.uploads.length, 2);
        expect(
          api.calls.any((call) => call.action == 'auth.user_info'),
          isTrue,
        );
        await fixture.finish(tester, session);
      },
    );
  }

  testWidgets('orientation is exported and reset restores the original cover', (
    tester,
  ) async {
    final api = PhotoApi()..fail = true;
    final bytes = await tester.runAsync(fixtureImage);
    final session = await fixture.mount(
      tester,
      ProfilePhotoEditor(
        kind: ProfilePhotoKind.cover,
        picker: (_) async => XFile.fromData(bytes!, name: 'fixture.png'),
      ),
      api: api,
      width: 320,
      language: 'ar',
      scale: 2,
      dark: true,
    );
    final l = tester.element(find.byType(ProfilePhotoEditor)).l10n;
    await tapAsync(tester, find.text(l.chooseFromLibrary));
    final save = find.byKey(const ValueKey('profile.photo.save'));
    await tapAsync(tester, find.byKey(const ValueKey('profile.photo.mirror')));
    await tapAsync(tester, save);
    expect(api.uploads, hasLength(1));
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(api.uploads.last.bytes);
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData())!.buffer.asUint8List();
      final sample = ((image.height ~/ 2) * image.width + image.width ~/ 6) * 4;
      expect(pixels.sublist(sample, sample + 3), [33, 150, 243]);
      image.dispose();
      codec.dispose();
    });
    await tapAsync(tester, find.byKey(const ValueKey('profile.photo.rotate')));
    final rotated = tester.widget<RawImage>(find.byType(RawImage).last).image!;
    expect(rotated.width, 300);
    expect(rotated.height, 900);
    await tapAsync(tester, find.text(l.reset));
    final reset = tester.widget<RawImage>(find.byType(RawImage).last).image!;
    expect(reset.width, 900);
    expect(reset.height, 300);
    await fixture.finish(tester, session);
  });

  testWidgets(
    'cover and avatar share the editor and preserve the form draft in RTL with large text',
    (tester) async {
      final session = await fixture.mount(
        tester,
        Builder(builder: (context) => AppForms.profile(context, previewSelf)),
        width: 320,
        language: 'ar',
        scale: 2,
        dark: true,
      );
      final form = tester.state<ActionFormState>(find.byType(ActionForm));
      form.setValue('displayname', 'Draft retained');
      await pumpUI(tester);
      final l = tester.element(find.byType(ActionForm)).l10n;
      for (final (finder, kind) in [
        (
          find.byKey(const ValueKey('profile.edit.cover')),
          ProfilePhotoKind.cover,
        ),
        (
          find.byKey(const ValueKey('profile.edit.avatar')),
          ProfilePhotoKind.avatar,
        ),
      ]) {
        await fixture.visibleTap(tester, finder);
        final library = find.byKey(const ValueKey('media.library'));
        expect(library, findsOneWidget);
        expect(
          find.descendant(
            of: library,
            matching: find.text(
              kind == ProfilePhotoKind.avatar
                  ? l.profileSetPhoto
                  : l.profileCoverPhoto,
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(library)).pop();
        await pumpUI(tester);
        expect(form.controllers['displayname']!.text, 'Draft retained');
      }
      await fixture.finish(tester, session);
    },
  );
}
