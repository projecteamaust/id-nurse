import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/services/mock_api_service.dart';

/// Collect (step 6) and Complete (step 7): frontend-only steps after DONE or PARTIAL.
void main() {
  late MockApiService api;

  tearDown(() => api.dispose());

  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.widgetWithText(OutlinedButton, d));
      await tester.pump();
    }
  }

  Future<void> addUnits(WidgetTester tester, int itemId, int units) async {
    final card = find.byKey(ValueKey('supply-$itemId'));
    for (var i = 0; i < units; i++) {
      await tester.tap(find.descendant(of: card, matching: find.widgetWithText(OutlinedButton, '+')));
      await tester.pump();
    }
    await tester.tap(find.descendant(of: card, matching: find.widgetWithText(FilledButton, 'Add')));
    await tester.pump();
  }

  Future<void> openCategory(WidgetTester tester, String category) async {
    await tester.tap(find.text(category));
    await tester.pumpAndSettle();
  }

  /// Advances fake time in small steps until [finder] shows up (at most [seconds]).
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int seconds = 30}) async {
    for (var i = 0; i < seconds * 4 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpAndSettle();
    expect(finder, findsWidgets, reason: 'not shown within $seconds s');
  }

  /// Patient 284913, 2 x gauze (slot 1) + 1 x adhesive dressing (slot 2) unless [lines]
  /// adds others, then authorize and wait for the robot. DONE lands on Collect;
  /// PARTIAL lands on the Prepare result, and we tap "Collect available items".
  Future<void> openCollect(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    Future<void> Function()? lines,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdNurseApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate card scan'));
    await tester.pumpAndSettle();
    await tapDigits(tester, '284913');
    await tester.tap(find.text('Find patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, select supplies'));
    await tester.pumpAndSettle();
    if (lines != null) {
      await lines();
    } else {
      await addUnits(tester, 1, 2);
      await addUnits(tester, 2, 1);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Review request'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Authorize request'));
    await pumpUntilFound(tester, find.textContaining(RegExp(r'^(Your items are ready|Collect available items)$')));
    if (find.text('Collect available items').evaluate().isNotEmpty) {
      await tester.tap(find.text('Collect available items'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Your items are ready'), findsOneWidget);
  }

  Future<void> tapCollected(WidgetTester tester) async {
    await tester.tap(find.text('I have collected my items'));
    await tester.pumpAndSettle();
  }

  Finder textIn(Key key, String text) => find.descendant(of: find.byKey(key), matching: find.text(text));

  /// 5 lines: gauze 2, dressing 1, IV set 1, gloves 4, masks 2.
  Future<void> fiveLines(WidgetTester tester) async {
    await addUnits(tester, 1, 2);
    await addUnits(tester, 2, 1);
    await openCategory(tester, 'IV and injections');
    await addUnits(tester, 3, 1);
    await openCategory(tester, 'Gloves and protection');
    await addUnits(tester, 5, 4);
    await addUnits(tester, 6, 2);
  }

  testWidgets('DONE: Collect lists the pickup box, Complete shows the receipt, then a new request',
      (tester) async {
    api = MockApiService();
    await openCollect(tester);

    expect(find.text('READY FOR COLLECTION'), findsOneWidget);
    expect(find.text('Take your items from the pickup box.'), findsOneWidget);
    expect(find.text('Pickup box'), findsOneWidget);
    expect(textIn(const Key('collect-list'), 'Sterile gauze pads'), findsOneWidget);
    expect(textIn(const Key('collect-list'), '2 units'), findsOneWidget);
    expect(textIn(const Key('collect-list'), 'Adhesive dressing'), findsOneWidget);
    expect(textIn(const Key('collect-list'), '1 unit'), findsOneWidget);
    expect(find.byKey(const Key('supervisor-alert')), findsNothing);
    // No door hardware: no open/close door actions.
    expect(find.textContaining('door'), findsNothing);
    expect(find.textContaining('Door'), findsNothing);

    await tapCollected(tester);
    expect(find.text('REQUEST COMPLETE'), findsOneWidget);
    expect(find.text('Your transaction is recorded'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^#\d+$')), findsOneWidget); // order number
    expect(find.text('Alex Morgan · 284913'), findsOneWidget);
    expect(find.text('Maya Chen'), findsWidgets); // receipt + top bar
    expect(find.text('Items dispensed'), findsOneWidget);
    expect(textIn(const Key('receipt-list'), 'Sterile gauze pads'), findsOneWidget);
    expect(textIn(const Key('receipt-list'), '2 units'), findsOneWidget);
    expect(textIn(const Key('receipt-list'), '1 unit'), findsOneWidget);
    expect(find.byKey(const Key('supervisor-alert')), findsNothing);

    await tester.tap(find.text('New request'));
    await tester.pumpAndSettle();
    expect(find.text('Which patient?'), findsOneWidget);
  });

  testWidgets('PARTIAL: Collect lists only what was dispensed; Complete shows what was not', (tester) async {
    api = MockApiService()..failPicksAfterUnits = 2; // tests only: the arm faults after 2 units
    await openCollect(tester);

    // Only the gauze (2 of 2) is in the box; the dressing (0 of 1) is not.
    expect(textIn(const Key('collect-list'), 'Sterile gauze pads'), findsOneWidget);
    expect(textIn(const Key('collect-list'), 'Adhesive dressing'), findsNothing);
    expect(
      find.text('Some items could not be dispensed. Please report the problem to your supervisor.'),
      findsOneWidget,
    );

    await tapCollected(tester);
    expect(find.text('Partly dispensed'), findsOneWidget);
    expect(find.text('Request recorded with missing items'), findsOneWidget);
    expect(textIn(const Key('receipt-list'), '2 of 2'), findsOneWidget);
    expect(textIn(const Key('receipt-list'), 'Dispensed'), findsOneWidget);
    expect(textIn(const Key('receipt-list'), '0 of 1'), findsOneWidget);
    expect(textIn(const Key('receipt-list'), 'Not dispensed'), findsOneWidget);
    expect(
      find.text('Some items were not dispensed. Please report the problem to your supervisor.'),
      findsOneWidget,
    );
  });

  group('fits the window without scrolling', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    void expectFits(WidgetTester tester, Size size, Key listKey, String button) {
      expect(find.byType(SingleChildScrollView), findsNothing);
      final card = tester.getRect(find.byKey(const Key('page-card')));
      expect(card.bottom, lessThanOrEqualTo(size.height));
      expect(tester.getRect(find.widgetWithText(FilledButton, button)).bottom, lessThanOrEqualTo(card.bottom));
      // All 5 lines are visible: the list does not need to scroll.
      final scrollable = find.descendant(of: find.byKey(listKey), matching: find.byType(Scrollable));
      expect(tester.state<ScrollableState>(scrollable.first).position.maxScrollExtent, 0);
    }

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('$label PARTIAL with 5 lines: Collect and Complete', (tester) async {
        api = MockApiService()..failPicksAfterUnits = 8; // the last line (masks) is not dispensed
        await openCollect(tester, size: size, lines: () => fiveLines(tester));
        expect(find.byKey(const Key('supervisor-alert')), findsOneWidget);
        expectFits(tester, size, const Key('collect-list'), 'I have collected my items');

        await tapCollected(tester);
        expect(textIn(const Key('receipt-list'), 'Procedure mask'), findsOneWidget);
        expectFits(tester, size, const Key('receipt-list'), 'New request');
      });
    }
  });
}
