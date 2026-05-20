import 'package:flutter_test/flutter_test.dart';
import 'package:suika_multi_player/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SuikaApp());
    expect(find.text('Suika'), findsOneWidget);
  });
}
