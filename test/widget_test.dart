import 'package:flutter_test/flutter_test.dart';
import 'package:global_coolers/main.dart';

void main() {
  testWidgets('App smoke test - renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify the app renders (Landing screen should show)
    expect(find.text('GLOBAL COOLERS'), findsOneWidget);
  });
}
