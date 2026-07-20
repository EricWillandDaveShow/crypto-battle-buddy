// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_battle_buddy/main.dart';

void main() {
  testWidgets('shows first-run notice when no flag is set', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CryptoBattleBuddyApp(showDebug: false));
    await tester.pumpAndSettle();

    expect(find.text('DEFINE'), findsOneWidget);
    expect(find.text('ENTER'), findsOneWidget);
  });
}
