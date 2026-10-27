import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/places_test.dart' as places;
import 'places_service_test.dart' as service;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  setUpAll(
    () => liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false),
  );
  places.main();
  service.main();
}
