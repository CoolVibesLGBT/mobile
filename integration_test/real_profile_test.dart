import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/appearance.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/screens/profile.dart';

/// Signs in to the local backend (debug default) and holds the real profile
/// on screen for capture. LOGIN_NICKNAME / LOGIN_PASSWORD default to demo.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real profile over initial_sync', (tester) async {
    await AppearanceCatalog.load();
    final session = Session(Api(), persistPreferences: false);
    await session.initialize();
    await session.authenticate({
      'nickname': const String.fromEnvironment(
        'LOGIN_NICKNAME',
        defaultValue: 'demo',
      ),
      'password': const String.fromEnvironment(
        'LOGIN_PASSWORD',
        defaultValue: 'demo',
      ),
    });
    await session.syncSystem();
    expect(session.api.token, startsWith('Bearer '));
    expect(session.system['preferences'], isNotNull);
    await tester.pumpWidget(
      CoolvibesApp(session: session, home: const ProfileScreen()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // ignore: avoid_print
    print('VISUAL_READY');
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await session.logout();
  });
}
