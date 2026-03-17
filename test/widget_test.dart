// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simple_erp/src/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('Renders login page', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Simple ERP'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
