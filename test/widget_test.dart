import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodieit/main.dart';
void main() {
  testWidgets('demo admin can sign in and see dashboard', (tester) async {
    await tester.pumpWidget(const FoodieitApp());
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'admin 123');
    await tester.enterText(find.byType(TextFormField).at(1), 'admin@example');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    // Admin now sees the Dashboard page with summary cards.
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Customers'), findsWidgets);
  });
}
