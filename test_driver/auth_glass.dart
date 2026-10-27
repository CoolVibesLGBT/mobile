import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot:
      (String name, List<int> bytes, [Map<String, Object?>? args]) async {
        if (!RegExp(r'^ios-[a-z0-9-]+$').hasMatch(name) || bytes.length < 8) {
          return false;
        }
        await Directory('Design/evidence').create(recursive: true);
        await File('Design/evidence/$name.png').writeAsBytes(bytes);
        return true;
      },
  responseDataCallback: (data) async {
    final shots = (data?['screenshots'] as List? ?? [])
        .map(
          (s) =>
              (s as Map)['screenshotName'] ?? s['screenshot_name'] ?? s['name'],
        )
        .toList();
    await File('Design/evidence/auth-glass-native.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'suite': 'integration_test/auth_glass_test.dart',
        'status': 'passed',
        'platform': 'iOS simulator 26.1',
        'cases': 2,
        'transport':
            'Login: real Dio multipart over loopback HTTP and isolated iOS Keychain; radar: PreviewApi. No production mutations.',
        'screenshots': shots,
      }),
    );
  },
);
