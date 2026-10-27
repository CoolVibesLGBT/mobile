import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/radar_interaction_test.dart' as flows;
import '../test/search_race_test.dart' as search;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  setUpAll(
    () => liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false),
  );
  flows.main(nativeRendering: true);
  search.main();
}
