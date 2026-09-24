import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_design/core/disclaimer.dart';

void main() {
  testWidgets('shows professional boundary disclaimer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DisclaimerBanner())));
    expect(find.textContaining('不构成结构'), findsOneWidget);
  });
}
