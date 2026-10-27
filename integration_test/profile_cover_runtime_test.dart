import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/profile_data.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/screens/profile.dart';
import 'package:coolvibes/screens/settings.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/profile_cover_test.dart' as fixture;
import '../test/account_menu_cover_test.dart' as account_fixture;
import '../test/support/ui_driver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  setUpAll(
    () => liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false),
  );
  fixture.main();
  account_fixture.main();
  testWidgets(
    'saved cover fills account menu and profile on iOS without changing user data',
    (tester) async {
      final api = Api();
      await api.restore();
      expect(api.token, isNotNull);
      final response = await api.call('auth.user_info');
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = profileUser(response['data']);
      session.uploads.owner = recordId(session.user);
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const MenuScreen()),
      );
      await tester.pump();
      final cover = find.byKey(const ValueKey('profile.cover'));
      bool decoded() => find
          .descendant(of: cover, matching: find.byType(RawImage))
          .evaluate()
          .any((e) => (e.widget as RawImage).image != null);
      for (var i = 0; i < 150 && !decoded(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(
        profileCover(session.user),
        isNotNull,
        reason: 'The existing account must have a saved cover.',
      );
      expect(cover, findsOneWidget);
      expect(
        decoded(),
        isTrue,
        reason: 'Cover must decode, not only create an image widget.',
      );
      final image = tester.getRect(cover);
      expect(
        image.width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
      fixture.checkCoverGeometry(
        tester,
        topInset: tester.view.viewPadding.top / tester.view.devicePixelRatio,
      );
      final original = object(object(session.user['cover'])['file']);
      final originalVariant = object(
        object(original['variants'])['image'],
      )['original'];
      expect(
        tester.widget<AppImage>(cover).source,
        assetUrl(originalVariant ?? original['url']),
      );
      final l = tester.element(find.byType(MenuScreen)).l10n;
      final edit = find.descendant(
        of: find.byType(AppHeader),
        matching: find.text(l.edit),
      );
      await tapUI(tester, edit);
      await pumpUI(tester);
      final editor = find.byType(ActionForm);
      expect(editor, findsOneWidget);
      final editorCover = find.descendant(
        of: find.byKey(const ValueKey('profile.edit.cover')),
        matching: find.byType(AppImage),
      );
      expect(
        tester.widget<AppImage>(editorCover).source,
        profileCover(session.user),
      );
      Navigator.of(tester.element(editor)).pop();
      await pumpUI(tester);
      expect(cover, findsOneWidget);
      await tapUI(tester, find.text(l.viewProfile));
      await pumpUI(tester);
      expect(find.byType(ProfileScreen), findsOneWidget);
      fixture.checkInfoOrder(tester);
      fixture.checkCoverGeometry(
        tester,
        topInset: tester.view.viewPadding.top / tester.view.devicePixelRatio,
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        'PROFILE_COVER_SERVICE decoded=true width=${image.width} height=${image.height} menu_top=${image.top} profile_top=${tester.getTopLeft(cover).dy} label_order=correct writes=0',
      );
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      api.dio.close();
    },
    skip: !const bool.fromEnvironment('PROFILE_COVER_SERVICE'),
  );
}
