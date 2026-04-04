import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/app.dart';

void main() {
  testWidgets('App loads home scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EcommerceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ANJANAM Ecommerce'), findsOneWidget);
    expect(find.text('Open Backend Debug Page'), findsOneWidget);
  });
}
