import 'package:integration_test/integration_test.dart';
import '../test/composer_context_test.dart' as flows;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      .shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'NATIVE_HOST_TOUCH',
  );
  flows.main();
}
