import 'package:flutter_test/flutter_test.dart';
import 'package:fiscal_shield_ai/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const FiscalShieldApp());
    await tester.pump();
    expect(find.text('财智哨兵'), findsOneWidget);
  });
}
