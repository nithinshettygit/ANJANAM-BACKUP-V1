import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Widget test harness is stable', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('widget-test-ok'),
          ),
        ),
      ),
    );

    expect(find.text('widget-test-ok'), findsOneWidget);
  });
}
