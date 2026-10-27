import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'debug/preview_api.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'core/appearance.dart';
import 'app.dart';
import 'vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'core/glass_licenses.dart';
export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerGlassLicenses();
  try {
    await liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  } catch (error, stack) {
    // Rendering has an in-library fallback; shader failure must not block login.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'Coolvibes glass initialization',
      ),
    );
  }
  await AppearanceCatalog.load();
  final gallery = kDebugMode && const bool.fromEnvironment('DEBUG_GALLERY');
  final session = Session(
    gallery ? PreviewApi(PreviewState.populated) : Api(),
    persistPreferences: !gallery,
  );
  runApp(CoolvibesApp(session: session));
  if (gallery) {
    session.ready = true;
  } else {
    session.initialize();
  }
}
