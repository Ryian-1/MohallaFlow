import 'package:flutter_test/flutter_test.dart';
import 'package:mohalla_flow/app.dart';

void main() {
  testWidgets('MohallaFlow splash screen navigates to login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MohallaFlowApp());

    expect(find.bySemanticsLabel('MohallaFlow'), findsOneWidget);

    expect(find.text('Preparing your community space'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
