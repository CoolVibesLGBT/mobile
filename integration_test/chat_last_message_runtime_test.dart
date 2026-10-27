import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/chat_last_message_test.dart' as previews;
import 'chat_list_service_test.dart' as service;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false),
  );
  previews.main();
  service.main();
}
