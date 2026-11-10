import 'package:flutter_test/flutter_test.dart';
import 'package:pick_file_example/main.dart';

void main() {
  testWidgets('Renders PickFileExampleApp home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PickFileExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Pick File Plugin Demo'), findsOneWidget);
    expect(find.text('Pick Single File'), findsOneWidget);
    expect(find.text('Pick Multiple Files'), findsOneWidget);
    expect(find.text('Selected Files (0)'), findsOneWidget);
  });
}
