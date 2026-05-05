import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_swiftbill/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const FocusSupermarketApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
