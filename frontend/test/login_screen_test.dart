import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/services/mock_api_service.dart';

void main() {
  late MockApiService api;

  setUp(() => api = MockApiService());
  tearDown(() => api.dispose());

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdNurseApp(api: api));
    await tester.pumpAndSettle();
  }

  Future<void> openEnterIdTab(WidgetTester tester) async {
    await tester.tap(find.text('Enter ID'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKeys(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.widgetWithText(OutlinedButton, d));
      await tester.pump();
    }
  }

  FilledButton findMyIdButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Find my ID'));

  testWidgets('shows the Identify screen with the Scan card tab first', (tester) async {
    await openApp(tester);
    expect(find.text('Identify yourself'), findsOneWidget);
    expect(find.text('Scan your nurse card or enter your ID.'), findsOneWidget);
    expect(find.text('Scan card'), findsOneWidget);
    expect(find.text('Hold your card against the reader below the screen'), findsOneWidget);
    expect(find.text('Simulate card scan'), findsOneWidget); // demo mode is on by default
    expect(find.text('Admin sign in'), findsOneWidget);
  });

  testWidgets('keypad builds the ID; Find my ID needs at least 4 digits', (tester) async {
    await openApp(tester);
    await openEnterIdTab(tester);

    await tapKeys(tester, '482');
    expect(find.text('482'), findsOneWidget);
    expect(findMyIdButton(tester).onPressed, isNull);

    await tapKeys(tester, '1');
    expect(findMyIdButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
    await tester.pump();
    expect(find.text('482'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pump();
    expect(find.text('482'), findsNothing);
  });

  testWidgets('keypad stops at 6 digits', (tester) async {
    await openApp(tester);
    await openEnterIdTab(tester);
    await tapKeys(tester, '1234567');
    expect(find.text('123456'), findsOneWidget);
  });

  testWidgets('unknown ID shows "No staff ID found"', (tester) async {
    await openApp(tester);
    await openEnterIdTab(tester);
    await tapKeys(tester, '9999');
    await tester.tap(find.text('Find my ID'));
    await tester.pumpAndSettle();
    expect(find.text('No staff ID found. Check the number and try again.'), findsOneWidget);
    expect(find.text('Identify yourself'), findsOneWidget);
  });

  testWidgets('switching tabs clears the error', (tester) async {
    await openApp(tester);
    await openEnterIdTab(tester);
    await tapKeys(tester, '9999');
    await tester.tap(find.text('Find my ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan card'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No staff ID found'), findsNothing);
  });

  testWidgets('correct ID signs in and opens the next screen', (tester) async {
    await openApp(tester);
    await openEnterIdTab(tester);
    await tapKeys(tester, '48216');
    await tester.tap(find.text('Find my ID'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Maya Chen'), findsOneWidget);

    // Sign out goes back to the login screen.
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Identify yourself'), findsOneWidget);
  });

  testWidgets('a keyboard card reader (digits + Enter) signs in', (tester) async {
    await openApp(tester);
    for (final key in [
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit6,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Reading card…'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Maya Chen'), findsOneWidget);
  });

  testWidgets('demo "Simulate card scan" button signs in the demo nurse', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Simulate card scan'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Maya Chen'), findsOneWidget);
  });
}
