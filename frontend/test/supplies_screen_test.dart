import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/services/mock_api_service.dart';

void main() {
  late MockApiService api;

  setUp(() => api = MockApiService());
  tearDown(() => api.dispose());

  /// Signs in the demo nurse, finds patient 284913 and opens the Supplies screen.
  Future<void> openSupplies(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdNurseApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate card scan'));
    await tester.pumpAndSettle();
    for (final d in '284913'.split('')) {
      await tester.tap(find.widgetWithText(OutlinedButton, d));
      await tester.pump();
    }
    await tester.tap(find.text('Find patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, select supplies'));
    await tester.pumpAndSettle();
  }

  Finder card(int itemId) => find.byKey(ValueKey('supply-$itemId'));
  Finder inCard(int itemId, Finder finder) => find.descendant(of: card(itemId), matching: finder);
  Finder stepButton(int itemId, String label) => inCard(itemId, find.widgetWithText(OutlinedButton, label));

  Future<void> tapTimes(WidgetTester tester, Finder finder, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(finder);
      await tester.pump();
    }
  }

  Future<void> addUnits(WidgetTester tester, int itemId, int units) async {
    await tapTimes(tester, stepButton(itemId, '+'), units);
    await tester.tap(inCard(itemId, find.widgetWithText(FilledButton, 'Add')));
    await tester.pump();
  }

  /// [button] finds a FilledButton/OutlinedButton (both are ButtonStyleButtons).
  bool enabled(WidgetTester tester, Finder button) => tester.widget<ButtonStyleButton>(button).onPressed != null;

  testWidgets('opens for the chosen patient with the first category selected', (tester) async {
    await openSupplies(tester);
    expect(find.text('PATIENT 284913'), findsOneWidget);
    expect(find.text('Supplies'), findsWidgets); // panel title and step tracker
    for (final category in ['Wound care', 'IV and injections', 'Gloves and protection']) {
      expect(find.text(category), findsWidgets);
    }
    expect(find.text('2 supplies'), findsOneWidget);
    expect(find.text('Sterile gauze pads'), findsOneWidget);
    expect(find.text('Adhesive dressing'), findsOneWidget);
    expect(find.text('Your request is empty'), findsOneWidget);
  });

  testWidgets('search placeholder uses the normal text style, not the wide keypad digits', (tester) async {
    await openSupplies(tester);
    final field = tester.widget<TextField>(find.byKey(const Key('supply-search')));
    final hint = field.decoration!.hintStyle!;
    expect(hint.letterSpacing, isNull);
    expect(hint.fontSize, field.style!.fontSize);
  });

  testWidgets('tapping a category switches the list', (tester) async {
    await openSupplies(tester);
    await tester.tap(find.text('Gloves and protection'));
    await tester.pumpAndSettle();
    expect(find.text('Nitrile gloves, M'), findsOneWidget);
    expect(find.text('Procedure mask'), findsOneWidget);
    expect(find.text('Sterile gauze pads'), findsNothing);
  });

  testWidgets('search looks in all categories; clearing it restores the category', (tester) async {
    await openSupplies(tester);
    await tester.enterText(find.byKey(const Key('supply-search')), 'gloves');
    await tester.pumpAndSettle();
    expect(find.text('Results for "gloves"'), findsOneWidget);
    expect(find.text('Nitrile gloves, M'), findsOneWidget);
    expect(find.text('1 supplies'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('supply-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No supplies match your search.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('supply-search')), '');
    await tester.pumpAndSettle();
    expect(find.text('Sterile gauze pads'), findsOneWidget);
  });

  testWidgets('stock chips: in stock, low, out of stock', (tester) async {
    await openSupplies(tester);
    expect(inCard(1, find.text('In stock')), findsOneWidget);
    expect(inCard(1, find.text('Slot 1')), findsOneWidget);
    expect(inCard(1, find.text('42 units available')), findsOneWidget);
    expect(inCard(2, find.text('Low · 9')), findsOneWidget);

    await tester.tap(find.text('IV and injections'));
    await tester.pumpAndSettle();
    expect(inCard(4, find.text('Out of stock')), findsOneWidget);
    expect(inCard(4, find.text('Unavailable for this request')), findsOneWidget);
    expect(inCard(4, find.text('Add')), findsNothing); // no stepper or Add
  });

  testWidgets('stepper: minus disabled at 0, plus stops at the stock', (tester) async {
    await openSupplies(tester);
    expect(enabled(tester, stepButton(2, '−')), isFalse);
    expect(enabled(tester, inCard(2, find.widgetWithText(FilledButton, 'Add'))), isFalse);

    await tapTimes(tester, stepButton(2, '+'), 9); // Adhesive dressing: 9 in stock
    expect(inCard(2, find.text('9')), findsOneWidget);
    expect(enabled(tester, stepButton(2, '+')), isFalse);
    expect(enabled(tester, stepButton(2, '−')), isTrue);
  });

  testWidgets('stepper stops at the order limit of 30', (tester) async {
    await openSupplies(tester);
    await tester.tap(find.text('Gloves and protection'));
    await tester.pumpAndSettle();
    await tapTimes(tester, stepButton(5, '+'), 30); // Nitrile gloves: 64 in stock
    expect(inCard(5, find.text('30')), findsOneWidget);
    expect(enabled(tester, stepButton(5, '+')), isFalse);
  });

  testWidgets('Add puts the item in the request; adding again lowers the limit; Remove empties it', (tester) async {
    await openSupplies(tester);
    await addUnits(tester, 2, 4);

    expect(find.text('Your request is empty'), findsNothing);
    expect(find.text('4 units'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('request-lines')), matching: find.text('Adhesive dressing')),
        findsOneWidget);
    expect(inCard(2, find.text('0')), findsOneWidget); // stepper reset

    // 9 in stock, 4 already requested: the stepper now stops at 5.
    await tapTimes(tester, stepButton(2, '+'), 6);
    expect(inCard(2, find.text('5')), findsOneWidget);
    await tester.tap(inCard(2, find.widgetWithText(FilledButton, 'Add')));
    await tester.pump();
    expect(find.text('9 units'), findsOneWidget);
    expect(enabled(tester, stepButton(2, '+')), isFalse);

    await tester.tap(find.text('Remove'));
    await tester.pump();
    expect(find.text('Your request is empty'), findsOneWidget);
    expect(find.text('0 units'), findsOneWidget);
  });

  testWidgets('Review request is enabled only with items', (tester) async {
    await openSupplies(tester);
    final review = find.widgetWithText(FilledButton, 'Review request');
    expect(tester.widget<FilledButton>(review).onPressed, isNull);

    await addUnits(tester, 1, 2);
    expect(tester.widget<FilledButton>(review).onPressed, isNotNull);
    await tester.tap(review);
    await tester.pump();
    expect(find.text('Review comes in a later step.'), findsOneWidget);
  });

  testWidgets('sign out clears the request', (tester) async {
    await openSupplies(tester);
    await addUnits(tester, 1, 2);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Identify yourself'), findsOneWidget);

    // Signing in again and choosing the same patient starts with an empty request.
    await tester.tap(find.text('Simulate card scan'));
    await tester.pumpAndSettle();
    for (final d in '284913'.split('')) {
      await tester.tap(find.widgetWithText(OutlinedButton, d));
      await tester.pump();
    }
    await tester.tap(find.text('Find patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, select supplies'));
    await tester.pumpAndSettle();
    expect(find.text('Your request is empty'), findsOneWidget);
  });

  group('fits the window; only the item list scrolls', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    for (final size in sizes) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await openSupplies(tester, size: size);
        await addUnits(tester, 1, 2);
        await addUnits(tester, 2, 1);

        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byKey(const Key('supply-list')), findsOneWidget);

        // The request panel reaches the bottom: only its own padding (24 x 1.25 at most) is below the button.
        final review = tester.getRect(find.widgetWithText(FilledButton, 'Review request'));
        expect(review.bottom, lessThanOrEqualTo(size.height));
        expect(review.bottom, greaterThanOrEqualTo(size.height - 31));
      });
    }
  });
}
