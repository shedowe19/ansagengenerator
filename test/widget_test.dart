import 'package:ansagengenerator/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the cross-platform announcement generator shell', (
    tester,
  ) async {
    await tester.pumpWidget(const AnsagengeneratorApp());
    expect(find.text('Ansagengenerator'), findsWidgets);
    expect(find.text('Zielbahnhof'), findsOneWidget);
  });
}
