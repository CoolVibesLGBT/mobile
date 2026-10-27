import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/appearance.dart';
import 'package:coolvibes/vendor/liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid;
import '../test/article_test.dart' as article;
import '../test/sheet_geometry_test.dart' as sheets;
import '../test/article_toolbar_test.dart' as toolbar;
import '../test/emoji_search_test.dart' as search;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await liquid.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
    await AppearanceCatalog.load();
  });
  article.main();
  sheets.main();
  toolbar.main();
  search.main();
}
