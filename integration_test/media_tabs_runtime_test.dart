import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/appearance.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/media_tabs_test.dart' as tabs;
import '../test/emoji_search_test.dart' as search;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
    await AppearanceCatalog.load();
  });
  tabs.main();
  search.main();
}
