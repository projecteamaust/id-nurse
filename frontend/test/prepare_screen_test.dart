import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/models/order.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/mock_api_service.dart';

/// MockApiService that counts GET /orders/{id} calls and can fail some of them.
class _TestApi extends MockApiService {
  _TestApi({super.pickInterval});

  int getOrderCalls = 0;
  int getOrderFailures = 0; // how many polls fail before they work again

  @override
  Future<Order> getOrder(int orderId) async {
    getOrderCalls++;
    if (getOrderFailures > 0) {
      getOrderFailures--;
      throw const ApiException(500, 'Server error');
    }
    return super.getOrder(orderId);
  }
}

void main() {
  late _TestApi api;

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

  /// Patient 284913, 2 x gauze (slot 1) + 1 x adhesive dressing (slot 2) unless [lines]
  /// adds others, then "Authorize request" -> Prepare.
  Future<void> openPrepare(
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
    await tester.pump(const Duration(seconds: 2)); // create + approve (600 ms each)
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

  Finder textIn(Key key, String text) => find.descendant(of: find.byKey(key), matching: find.text(text));

  testWidgets('shows progress per item from qty_dispensed, then goes to Collect on DONE', (tester) async {
    api = _TestApi(pickInterval: const Duration(seconds: 3)); // slow robot: time to look at each step
    await openPrepare(tester);

    expect(find.text('PLEASE WAIT NEARBY'), findsOneWidget);
    expect(find.text('Preparing your request'), findsOneWidget);
    expect(find.text('Item 1 of 2'), findsOneWidget);
    expect(find.text('Moving to slot 1 · Sterile gauze pads'), findsOneWidget);
    expect(find.text('0 of 3 units picked'), findsOneWidget);
    expect(find.text('About 3 sec'), findsOneWidget);
    for (final stage in ['Request received', 'Retrieving items', 'Ready for collection']) {
      expect(find.text(stage), findsOneWidget);
    }

    await pumpUntilFound(tester, find.text('Item 2 of 2'));
    expect(find.text('Moving to slot 2 · Adhesive dressing'), findsOneWidget);
    expect(find.text('2 of 3 units picked'), findsOneWidget);
    expect(find.text('Slot 1 ✓'), findsOneWidget); // finished slot in the cabinet

    await pumpUntilFound(tester, find.text('Your items are ready'));
    await tester.tap(find.text('New request'));
    await tester.pumpAndSettle();
    expect(find.text('Which patient?'), findsOneWidget);
  });

  testWidgets('there is no cancel button while the robot works', (tester) async {
    api = _TestApi(pickInterval: const Duration(seconds: 3));
    await openPrepare(tester);
    expect(find.text('Preparing your request'), findsOneWidget);
    expect(find.textContaining('Cancel'), findsNothing);
    expect(find.textContaining('cancel'), findsNothing);
    await pumpUntilFound(tester, find.text('Your items are ready'));
  });

  testWidgets('polls about every 1.5 s and stops when the order is final', (tester) async {
    api = _TestApi(pickInterval: const Duration(seconds: 3));
    await openPrepare(tester);

    final before = api.getOrderCalls;
    await tester.pump(const Duration(seconds: 6));
    expect(api.getOrderCalls - before, inInclusiveRange(3, 5)); // 6 s / 1.5 s = 4

    await pumpUntilFound(tester, find.text('Your items are ready'));
    final afterFinal = api.getOrderCalls;
    await tester.pump(const Duration(seconds: 6));
    expect(api.getOrderCalls, afterFinal); // no more polling
  });

  testWidgets('a failed poll shows a warning and polling recovers', (tester) async {
    api = _TestApi(pickInterval: const Duration(seconds: 3))..getOrderFailures = 1;
    await openPrepare(tester);
    expect(find.text('Connection lost. Trying again…'), findsOneWidget);

    await pumpUntilFound(tester, find.text('Preparing your request'));
    expect(find.text('Connection lost. Trying again…'), findsNothing);
    await pumpUntilFound(tester, find.text('Your items are ready'));
  });

  testWidgets('PARTIAL shows what was and was not dispensed; collect the rest', (tester) async {
    api = _TestApi()..failPicksAfterUnits = 2; // tests only: the arm faults after 2 units
    await openPrepare(tester);
    await pumpUntilFound(tester, find.text('Some items could not be dispensed'));

    expect(find.text('Partly dispensed'), findsOneWidget);
    expect(find.text('Collect the items that were dispensed. The missing items are recorded.'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Dispensed'), findsOneWidget);
    expect(find.text('0 of 1'), findsOneWidget);
    expect(find.text('Not dispensed'), findsOneWidget);
    expect(textIn(const Key('result-list'), 'Sterile gauze pads'), findsOneWidget);
    expect(textIn(const Key('result-list'), 'Adhesive dressing'), findsOneWidget);

    await tester.tap(find.text('Collect available items'));
    await tester.pumpAndSettle();
    expect(find.text('Your items are ready'), findsOneWidget);
  });

  testWidgets('FAILED shows nothing was dispensed; start a new request', (tester) async {
    api = _TestApi()..failPicksAfterUnits = 0; // tests only: the arm faults on the first pick
    await openPrepare(tester);
    await pumpUntilFound(tester, find.text('Your request could not be dispensed'));

    expect(find.text('!'), findsOneWidget);
    expect(find.text('Not dispensed'), findsNWidgets(3)); // the heading chip + both rows
    expect(find.text('0 of 2'), findsOneWidget);
    expect(find.text('0 of 1'), findsOneWidget);
    expect(find.text('Collect available items'), findsNothing);

    await tester.tap(find.text('Start a new request'));
    await tester.pumpAndSettle();
    expect(find.text('Which patient?'), findsOneWidget);
  });

  group('fits the window without scrolling', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    void expectCardFills(WidgetTester tester, Size size) {
      expect(find.byType(SingleChildScrollView), findsNothing);
      final card = tester.getRect(find.byKey(const Key('page-card')));
      expect(card.bottom, greaterThanOrEqualTo(size.height - 36));
      expect(card.bottom, lessThanOrEqualTo(size.height));
    }

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('$label preparing', (tester) async {
        api = _TestApi(pickInterval: const Duration(seconds: 3));
        await openPrepare(tester, size: size);
        expect(find.text('Preparing your request'), findsOneWidget);
        expectCardFills(tester, size);
        final card = tester.getRect(find.byKey(const Key('page-card')));
        expect(tester.getRect(find.byKey(const ValueKey('drawer-6'))).bottom, lessThanOrEqualTo(card.bottom));
        // The bottom of the "Now working" panel is inside the card too.
        expect(tester.getRect(find.textContaining('units picked')).bottom, lessThanOrEqualTo(card.bottom));
        await pumpUntilFound(tester, find.text('Your items are ready'));
      });

      testWidgets('$label PARTIAL with 5 rows', (tester) async {
        api = _TestApi()..failPicksAfterUnits = 1;
        await openPrepare(tester, size: size, lines: () async {
          await addUnits(tester, 1, 2);
          await addUnits(tester, 2, 1);
          await openCategory(tester, 'IV and injections');
          await addUnits(tester, 3, 1);
          await openCategory(tester, 'Gloves and protection');
          await addUnits(tester, 5, 4);
          await addUnits(tester, 6, 2);
        });
        await pumpUntilFound(tester, find.text('Some items could not be dispensed'));
        expectCardFills(tester, size);
        expect(textIn(const Key('result-list'), 'Procedure mask'), findsOneWidget);
        expect(
          tester
              .state<ScrollableState>(
                  find.descendant(of: find.byKey(const Key('result-list')), matching: find.byType(Scrollable)))
              .position
              .maxScrollExtent,
          0,
        );
        final button = tester.getRect(find.widgetWithText(FilledButton, 'Collect available items'));
        expect(button.bottom, lessThanOrEqualTo(size.height));
      });
    }
  });
}
