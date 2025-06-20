// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:challenge_and_risk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arabic Quiz Game smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChallengeAndRiskApp());

    // Verify that the home screen loads with the Arabic title
    expect(find.text('التحدي والمخاطرة'), findsOneWidget);
    expect(find.text('مرحباً بكم في لعبة التحدي والمخاطرة!'), findsOneWidget);
  });
}
