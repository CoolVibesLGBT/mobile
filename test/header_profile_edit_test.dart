import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/profile_header.dart';
import 'package:coolvibes/components/workspace_menu.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'package:coolvibes/screens/app_forms.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/screens/settings.dart';
import 'package:coolvibes/screens/preferences.dart';
import 'package:coolvibes/screens/location_picker.dart';
import 'support/profile_api.dart';
import 'support/ui_driver.dart';

Future<Session> mount(
  WidgetTester tester,
  Widget home, {
  ProfileApi? api,
  double width = 390,
  bool dark = false,
  String language = 'tr',
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width * 3, 2532);
  tester.view.devicePixelRatio = 3;
  tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  addTearDown(tester.view.reset);
  final session = Session(api ?? ProfileApi(), persistPreferences: false)
    ..ready = true
    ..user = previewSelf
    ..system = previewSystem
    ..locale = Locale(language)
    ..themeMode = dark ? ThemeMode.dark : ThemeMode.light;
  await tester.pumpWidget(
    CoolvibesApp(
      session: session,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: home,
        ),
      ),
    ),
  );
  await pumpUI(tester);
  return session;
}

Future<void> finish(WidgetTester tester, Session session) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await pumpUI(tester);
  session.dispose();
}

Future<void> visibleTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await pumpUI(tester);
  await tester.tap(finder);
  await pumpUI(tester);
}

void main() {
  for (final variant in [
    (390.0, false, 'tr'),
    (320.0, true, 'tr'),
    (390.0, true, 'ar'),
  ]) {
    final (width, dark, language) = variant;
    testWidgets(
      'nearby header controls stay aligned and separate: $width/$language',
      (tester) async {
        final session = await mount(
          tester,
          const NearbyScreen(),
          width: width,
          dark: dark,
          language: language,
        );
        final header = find.byType(AppHeader);
        final segments = find.descendant(
          of: header,
          matching: find.byType(AppSegments<String>),
        );
        final rect = tester.getRect(segments);
        expect(rect.height, 44);
        expect(rect.top, closeTo(59, 1));
        expect(rect.width / 3, greaterThanOrEqualTo(44));
        if (width == 390) expect(rect.center.dx, closeTo(width / 2, 1));
        for (final button
            in find
                .descendant(of: header, matching: find.byType(AppIconButton))
                .evaluate()) {
          expect(
            rect.overlaps(tester.getRect(find.byWidget(button.widget))),
            isFalse,
          );
        }
        final l = tester.element(header).l10n;
        await tester.tap(find.bySemanticsLabel(l.list));
        await pumpUI(tester);
        expect(tester.widget<AppSegments<String>>(segments).selected, 'list');
        await tester.tap(find.bySemanticsLabel(l.grid));
        await pumpUI(tester);
        await tester.tap(find.bySemanticsLabel(l.grid));
        await pumpUI(tester);
        await tester.tap(find.text(l.columns2(3)));
        await pumpUI(tester);
        expect(tester.widget<AppSegments<String>>(segments).selected, 'grid');
        final list = tester.widget<RecordList>(find.byType(RecordList));
        expect(list.columns, 3);
        expect(
          tester
              .widget<AppScaffold>(find.byType(AppScaffold).first)
              .extendBodyBehindAppBar,
          isTrue,
        );
        await finish(tester, session);
      },
    );
  }

  testWidgets(
    'avatar menu uses the account header and opens the shared profile editor',
    (tester) async {
      final session = await mount(tester, const NearbyScreen());
      await tester.tap(find.byType(WorkspaceMenuButton));
      await pumpUI(tester);
      expect(find.byType(MenuScreen), findsOneWidget);
      final header = tester.widget<AppHeader>(find.byType(AppHeader).last);
      expect(header.title, isNull);
      final account = find.byType(ProfileHeader);
      expect(
        tester.getSize(
          find.descendant(of: account, matching: find.byType(Avatar)),
        ),
        const Size(100, 100),
      );
      expect(find.text('@deniz'), findsOneWidget);
      expect(find.byType(AppSection), findsWidgets);
      await tester.tap(find.text('Düzenle'));
      await pumpUI(tester);
      expect(find.byType(ActionForm), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(ActionForm))),
        isA<CupertinoPageRoute>(),
      );
      final avatar = find.byKey(const ValueKey('profile.edit.avatar'));
      expect(tester.widget<AppPressable>(avatar).onPressed, isNotNull);
      expect(
        tester.getSize(
          find.descendant(of: avatar, matching: find.byType(Avatar)),
        ),
        const Size(128, 128),
      );
      await finish(tester, session);
    },
  );

  for (final language in ['tr', 'ar']) {
    testWidgets(
      'profile editor preserves its draft across details, privacy, date and location: $language',
      (tester) async {
        final api = ProfileApi();
        final session = await mount(
          tester,
          Builder(builder: (context) => AppForms.profile(context, previewSelf)),
          api: api,
          language: language,
          width: language == 'ar' ? 320 : 390,
          scale: language == 'ar' ? 2 : 1,
          dark: language == 'ar',
        );
        final state = tester.state<ActionFormState>(find.byType(ActionForm));
        final l = tester.element(find.byType(ActionForm)).l10n;
        final name = find.descendant(
          of: find.byKey(const ValueKey('form.displayname')),
          matching: find.byType(TextField),
        );
        if (name.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            name,
            250,
            scrollable: find
                .descendant(
                  of: find.byType(ActionForm),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tester.ensureVisible(name);
        await tester.enterText(name, 'Korunan isim');
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpUI(tester);
        await visibleTap(tester, find.text(l.attributes));
        expect(
          tester.widget<PreferencesSliver>(find.byType(PreferencesSliver)).kind,
          'attributes',
        );
        expect(find.text(l.save), findsNothing);
        await visibleTap(tester, find.text(l.profileInfo));
        expect(state.controllers['displayname']!.text, 'Korunan isim');
        await visibleTap(tester, find.text(l.profilePrivacy));
        await visibleTap(tester, find.text(l.profilePrivacyPrivate));
        expect(state.controllers['privacy_level']!.text, 'private');
        await visibleTap(
          tester,
          find.byKey(const ValueKey('profile.edit.birthdate')),
        );
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .onDateTimeChanged(DateTime(1995, 4, 12));
        await tester.tap(find.text(l.save).last);
        await pumpUI(tester);
        expect(state.controllers['date_of_birth']!.text, '1995-04-12');
        await visibleTap(
          tester,
          find.byKey(const ValueKey('profile.edit.location')),
        );
        expect(find.byType(LocationPickerScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(LocationPickerScreen))).pop({
          'latitude': 38.4,
          'longitude': 27.1,
          'address': 'İzmir',
          'country_code': 'TR',
          'timezone': 'Europe/Istanbul',
        });
        await pumpUI(tester);
        expect(state.controllers['displayname']!.text, 'Korunan isim');
        await visibleTap(
          tester,
          find.byKey(const ValueKey('profile.edit.location')),
        );
        final picker = tester.widget<LocationPickerScreen>(
          find.byType(LocationPickerScreen),
        );
        expect(picker.initial?['latitude'], 38.4);
        Navigator.of(tester.element(find.byType(LocationPickerScreen))).pop();
        await pumpUI(tester);
        await tester.tap(find.text(l.save));
        await pumpUI(tester);
        final sent = api.calls
            .where((c) => c.action == 'user.update_profile')
            .single
            .body;
        expect(sent['displayname'], 'Korunan isim');
        expect(sent['privacy_level'], 'private');
        expect(sent['date_of_birth'], '1995-04-12');
        expect(sent['location[latitude]'], 38.4);
        expect(sent['location[longitude]'], 27.1);
        expect(sent['location[display]'], 'İzmir');
        expect(sent['location[country_code]'], 'TR');
        expect(sent['location[timezone]'], 'Europe/Istanbul');
        expect(sent['location[contentable_type]'], 'users');
        expect(sent.containsKey('location'), isFalse);
        await finish(tester, session);
      },
    );
  }
}
