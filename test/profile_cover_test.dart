import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/profile_header.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/design/app_design.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'profile_presentation_test.dart' as fixture;
import 'support/profile_api.dart';
import 'support/ui_driver.dart';

const cover = {
  'file': {
    'url': '/static/cover-original.jpg',
    'variants': {
      'image': {
        'large': {'url': '/static/cover-large.jpg'},
      },
    },
  },
};
final coverFinder = find.byKey(const ValueKey('profile.cover'));

void checkCoverGeometry(WidgetTester tester, {required double topInset}) {
  final image = tester.getRect(coverFinder);
  final avatar = find.byKey(const ValueKey('profile.avatar.surface'));
  expect(image.top, 0);
  expect(image.height, AppDesign.profileCoverHeight + topInset);
  expect(tester.getRect(avatar).center.dy, image.bottom);
  final background =
      tester.widget<Container>(avatar).decoration! as BoxDecoration;
  expect(background.color!.a, 1);
  for (final opacity in tester.widgetList<Opacity>(
    find.ancestor(of: avatar, matching: find.byType(Opacity)),
  )) {
    expect(opacity.opacity, 1, reason: 'A noninteractive avatar must not dim.');
  }
}

void checkInfoOrder(WidgetTester tester) {
  final rows = tester
      .widgetList<ProfileInfoRow>(find.byType(ProfileInfoRow))
      .toList();
  final l = tester.element(find.byType(ProfileHeader)).l10n;
  for (final label in [l.username, l.profileJoined]) {
    final row = rows.singleWhere((row) => row.label == label);
    final scope = find.byWidget(row);
    final heading = find.descendant(of: scope, matching: find.text(row.label));
    final value = find.descendant(
      of: scope,
      matching: find.byType(SelectableText),
    );
    expect(
      tester.getBottomLeft(heading).dy,
      lessThan(tester.getTopLeft(value).dy),
    );
  }
}

void main() {
  testWidgets(
    'saved cover appears, updates and disappears without reopening own profile',
    (tester) async {
      final api = ProfileApi()..self['cover'] = cover;
      final session = await fixture.mountProfile(tester, api, own: true);
      expect(
        tester.widget<AppImage>(coverFinder).source,
        assetUrl('/static/cover-original.jpg'),
      );
      final image = tester.getRect(coverFinder);
      expect(image.width, 390);
      checkCoverGeometry(tester, topInset: 59);
      expect(
        tester.widget<AppHeader>(find.byType(AppHeader)).systemOverlayStyle,
        SystemUiOverlayStyle.light,
      );
      checkInfoOrder(tester);
      api.self['cover'] = {
        'file': {'url': '/static/replacement.jpg'},
      };
      await session.refreshUser();
      await pumpUI(tester);
      expect(
        tester.widget<AppImage>(coverFinder).source,
        assetUrl('/static/replacement.jpg'),
      );
      api.self.remove('cover');
      await session.refreshUser();
      await pumpUI(tester);
      expect(coverFinder, findsNothing);
      final noCoverAvatar = tester.getRect(
        find.descendant(
          of: find.byType(ProfileHeader),
          matching: find.byType(Avatar),
        ),
      );
      expect(noCoverAvatar.top, closeTo(81, 1));
      await fixture.finishProfile(tester, session);
    },
  );

  for (final language in ['tr', 'ar']) {
    testWidgets(
      'peer cover and info order remain readable at large text in $language',
      (tester) async {
        final api = ProfileApi()..peer['cover_image'] = cover;
        final session = await fixture.mountProfile(
          tester,
          api,
          language: language,
          dark: language == 'ar',
          scale: 2,
          size: const Size(320, 844),
        );
        expect(
          tester.widget<AppImage>(coverFinder).source,
          assetUrl('/static/cover-original.jpg'),
        );
        expect(tester.getSize(coverFinder).width, 320);
        checkCoverGeometry(tester, topInset: 59);
        checkInfoOrder(tester);
        await fixture.revealTabs(tester);
        expect(
          find.byKey(const ValueKey('profile.tabs')).hitTestable(),
          findsOneWidget,
        );
        final tabs = fixture.profileTabs;
        for (var i = 0; i < 5 && tester.getTopLeft(tabs).dy > 106; i++) {
          await tester.drag(
            find.byType(NestedScrollView),
            const Offset(0, -400),
          );
          await pumpUI(tester);
        }
        expect(tester.getTopLeft(tabs).dy, closeTo(105, 1));
        final header = tester.widget<AppHeader>(find.byType(AppHeader));
        expect(header.systemOverlayStyle, isNull);
        expect((header.title! as Opacity).opacity, 1);
        await fixture.finishProfile(tester, session);
      },
    );
  }
}
