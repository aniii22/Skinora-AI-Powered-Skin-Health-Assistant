
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Skinora dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SkinoraApp());

    expect(find.text('Skinora'), findsOneWidget);
    expect(find.text('Your skin, your glow ✨'), findsOneWidget);
    expect(find.text('Welcome to Skinora'), findsOneWidget);
  });
}
