import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/services/mock_api_service.dart';

void main() {
  late MockApiService api;

  setUp(() => api = MockApiService());
  tearDown(() => api.dispose());

  /// Opens the app and signs in the demo nurse, which lands on the Patient screen.
  Future<void> openPatientScreen(WidgetTester tester, {Size size = const Size(1280, 1100)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdNurseApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate card scan'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKeys(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.widgetWithText(OutlinedButton, d));
      await tester.pump();
    }
  }

  Future<void> findPatient(WidgetTester tester, String fileNumber) async {
    await tapKeys(tester, fileNumber);
    await tester.tap(find.text('Find patient'));
    await tester.pumpAndSettle();
  }

  FilledButton findPatientButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Find patient'));

  testWidgets('login leads to "Which patient?" with nurse, step tracker and privacy note', (tester) async {
    await openPatientScreen(tester);
    expect(find.text('Which patient?'), findsOneWidget);
    expect(find.text('Enter the patient file number.'), findsOneWidget);
    expect(find.text('Patient details are used only for this supply request.'), findsOneWidget);
    expect(find.text('File number'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);
    expect(find.text('Ward 4 · Surgical'), findsOneWidget);
    for (final step in ['Identify', 'Patient', 'Supplies', 'Review', 'Prepare', 'Collect', 'Complete']) {
      expect(find.text(step), findsOneWidget);
    }
  });

  testWidgets('Find patient needs at least 5 digits; keypad stops at 8', (tester) async {
    await openPatientScreen(tester);
    await tapKeys(tester, '2849');
    expect(findPatientButton(tester).onPressed, isNull);

    await tapKeys(tester, '1');
    expect(findPatientButton(tester).onPressed, isNotNull);

    await tapKeys(tester, '3456');
    expect(find.text('28491345'), findsOneWidget);
  });

  testWidgets('a known file number shows the patient card', (tester) async {
    await openPatientScreen(tester);
    await findPatient(tester, '284913');

    expect(find.text('Is this the right patient?'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget); // initials avatar
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('File 284913 · Age 34'), findsOneWidget);
    expect(find.text('2B-12'), findsOneWidget);
    expect(find.text('T81.4'), findsOneWidget);
    expect(find.text('Yes, select supplies'), findsOneWidget);
    expect(find.text('No, enter again'), findsOneWidget);
  });

  testWidgets('an unknown file number shows an error and stays on the keypad', (tester) async {
    await openPatientScreen(tester);
    await findPatient(tester, '999999');

    expect(find.text('No patient with this file number. Check the number and try again.'), findsOneWidget);
    expect(find.text('Which patient?'), findsOneWidget);
    expect(find.text('Is this the right patient?'), findsNothing);

    // Changing the number hides the error.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
    await tester.pump();
    expect(find.textContaining('No patient with this file number'), findsNothing);
  });

  testWidgets('"No, enter again" goes back to an empty keypad', (tester) async {
    await openPatientScreen(tester);
    await findPatient(tester, '284913');
    await tester.tap(find.text('No, enter again'));
    await tester.pumpAndSettle();

    expect(find.text('Which patient?'), findsOneWidget);
    expect(find.text('284913'), findsNothing);
    expect(findPatientButton(tester).onPressed, isNull);
  });

  testWidgets('"Yes, select supplies" says the next step comes later', (tester) async {
    await openPatientScreen(tester);
    await findPatient(tester, '548220');
    expect(find.text('Sam Taylor'), findsOneWidget);
    await tester.tap(find.text('Yes, select supplies'));
    await tester.pump();
    expect(find.text('Supply selection comes in a later step.'), findsOneWidget);
  });

  testWidgets('Sign out returns to the login screen', (tester) async {
    await openPatientScreen(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Identify yourself'), findsOneWidget);
  });

  group('fills the window without scrolling', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('$label entry with error', (tester) async {
        await openPatientScreen(tester, size: size);
        await findPatient(tester, '999999');
        expect(find.textContaining('No patient with this file number'), findsOneWidget);

        // No page scroll view, and the card reaches down to the bottom of the window
        // (only the page padding, at most 28 x 1.25 = 35 px, is left below it).
        expect(find.byType(SingleChildScrollView), findsNothing);
        final card = tester.getRect(find.byKey(const Key('page-card')));
        expect(card.bottom, greaterThanOrEqualTo(size.height - 36));
        expect(card.bottom, lessThanOrEqualTo(size.height));

        final button = tester.getRect(find.widgetWithText(FilledButton, 'Find patient'));
        expect(button.bottom, lessThanOrEqualTo(card.bottom));
      });

      testWidgets('$label confirm', (tester) async {
        await openPatientScreen(tester, size: size);
        await findPatient(tester, '284913');
        expect(find.byType(SingleChildScrollView), findsNothing);
        final button = tester.getRect(find.widgetWithText(OutlinedButton, 'No, enter again'));
        expect(button.bottom, lessThanOrEqualTo(size.height));
      });
    }

    testWidgets('keypad and heading are bigger on a tall window than on a short one', (tester) async {
      Future<(double, double)> measure(Size size) async {
        await openPatientScreen(tester, size: size);
        final key = tester.getSize(find.widgetWithText(OutlinedButton, '5')).height;
        final heading = tester.getSize(find.text('Which patient?')).height;
        // Sign out so the next openPatientScreen starts from the login screen again.
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        return (key, heading);
      }

      final (shortKey, shortHeading) = await measure(const Size(1280, 720));
      final (tallKey, tallHeading) = await measure(const Size(1920, 1080));
      expect(tallKey, greaterThan(shortKey));
      expect(tallHeading, greaterThan(shortHeading));
      expect(tallKey, lessThanOrEqualTo(96)); // upper limit
    });
  });

  testWidgets('very small window scrolls instead of overflowing', (tester) async {
    await openPatientScreen(tester, size: const Size(1024, 560));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('narrow tablet portrait stacks the layout without overflow', (tester) async {
    await openPatientScreen(tester, size: const Size(600, 1000));
    expect(find.text('Which patient?'), findsOneWidget);
    await findPatient(tester, '284913');
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
