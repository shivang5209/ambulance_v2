import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Ambulance v2'),
        ),
      ),
    );

    expect(find.text('Ambulance v2'), findsOneWidget);
  });
}
