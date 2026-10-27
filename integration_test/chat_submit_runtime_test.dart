import 'package:integration_test/integration_test.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import 'package:flutter_test/flutter_test.dart';
import '../test/chat_submit_test.dart' as submit;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  });
  submit.main();
}
