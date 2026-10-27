import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/secondary_screens_test.dart' as screens;
import 'secondary_service_test.dart' as service;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  setUpAll(
    () => liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false),
  );
  screens.main();
  service.main();
}
