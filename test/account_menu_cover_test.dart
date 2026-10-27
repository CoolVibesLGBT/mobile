import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/workspace_menu.dart';
import 'package:coolvibes/design/app_design.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'package:coolvibes/screens/discover.dart';
import 'package:coolvibes/screens/profile.dart';
import 'package:coolvibes/screens/settings.dart';
import 'header_profile_edit_test.dart' as fixture;
import 'profile_cover_test.dart' as cover_fixture;
import 'support/profile_api.dart';
import 'support/ui_driver.dart';

Finder menuHeader() => find.descendant(
  of: find.byType(MenuScreen),
  matching: find.byType(AppHeader),
);

Finder backButton(WidgetTester tester) {
  final header = find.byType(AppHeader).last;
  final label = MaterialLocalizations.of(
    tester.element(header),
  ).backButtonTooltip;
  return find.descendant(
    of: header,
    matching: find.byWidgetPredicate(
      (widget) => widget is AppIconButton && widget.tooltip == label,
    ),
  );
}

void main() {
  for (final language in ['tr', 'ar']) {
    testWidgets('account menu cover reaches top and controls work: $language', (
      tester,
    ) async {
      final api = ProfileApi()..self['cover'] = cover_fixture.cover;
      final session = await fixture.mount(
        tester,
        const NearbyScreen(),
        api: api,
        language: language,
        width: language == 'ar' ? 320 : 390,
        dark: language == 'ar',
        scale: language == 'ar' ? 2 : 1,
      );
      if (const bool.fromEnvironment('NATIVE_HOST_TOUCH')) {
        tester.view.reset();
      }
      final topInset =
          tester.view.viewPadding.top / tester.view.devicePixelRatio;
      await session.refreshUser();
      await pumpUI(tester);
      await tapUI(tester, find.byType(WorkspaceMenuButton));
      await pumpUI(tester);
      expect(find.byType(MenuScreen), findsOneWidget);
      cover_fixture.checkCoverGeometry(tester, topInset: topInset);
      final l = tester.element(menuHeader()).l10n;
      final edit = find.descendant(
        of: menuHeader(),
        matching: find.text(l.edit),
      );
      final back = backButton(tester);
      expect(
        tester.getRect(edit).center.dy,
        closeTo(topInset + AppDesign.headerHeight / 2, 1),
      );
      expect(tester.getRect(back).top, closeTo(topInset, 1));
      expect(tester.getRect(edit).overlaps(tester.getRect(back)), isFalse);
      expect(
        tester.widget<AppHeader>(menuHeader()).systemOverlayStyle,
        SystemUiOverlayStyle.light,
      );

      await tapUI(tester, edit);
      await pumpUI(tester);
      expect(find.byType(ActionForm), findsOneWidget);
      await tapUI(tester, backButton(tester));
      await pumpUI(tester);
      expect(find.byType(ActionForm), findsNothing);
      cover_fixture.checkCoverGeometry(tester, topInset: topInset);

      final profile = find.text(l.viewProfile);
      await tester.ensureVisible(profile);
      await pumpUI(tester);
      await tapUI(tester, profile);
      await pumpUI(tester);
      expect(find.byType(ProfileScreen), findsOneWidget);
      cover_fixture.checkCoverGeometry(tester, topInset: topInset);
      await tapUI(tester, backButton(tester));
      await pumpUI(tester);

      final list = find.descendant(
        of: find.byType(MenuScreen),
        matching: find.byType(ListView),
      );
      await tester.drag(list, const Offset(0, -450));
      await pumpUI(tester);
      expect(tester.widget<AppHeader>(menuHeader()).systemOverlayStyle, isNull);
      expect(backButton(tester).hitTestable(), findsOneWidget);
      await tapUI(tester, backButton(tester));
      await pumpUI(tester);
      expect(find.byType(MenuScreen), findsNothing);
      expect(find.byType(NearbyScreen), findsOneWidget);
      await fixture.finish(tester, session);
    });
  }
}
