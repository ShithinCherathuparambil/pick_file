import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pick_file/pick_file.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clearCache completes without error', (
    WidgetTester tester,
  ) async {
    // Tests that host API integration works without throwing errors.
    await expectLater(PickFile.clearCache(), completes);
  });
}
