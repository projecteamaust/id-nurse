import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/models/order.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/mock_api_service.dart';

/// MockApiService that can fail on purpose and counts the order calls.
class _TestApi extends MockApiService {
  int createCalls = 0;
  int approveCalls = 0;
  ApiException? createError; // thrown by every createOrder
  int approveFailures = 0; // how many approveOrder calls fail before they work

  @override
  Future<Order> createOrder(String patientFileNumber, List<OrderLineRequest> items) async {
    createCalls++;
    if (createError != null) throw createError!;
    return super.createOrder(patientFileNumber, items);
  }

  @override
  Future<Order> approveOrder(int orderId) async {
    approveCalls++;
    if (approveFailures > 0) {
      approveFailures--;
      throw const ApiException(500, 'Server error');
    }
    return super.approveOrder(orderId);
  }
}

void main() {
  late _TestApi api;

  setUp(() => api = _TestApi());
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

  /// Signs in, picks patient 284913, adds 2 x gauze and 1 x adhesive dressing
  /// (plus [extra] lines), then opens Review.
  Future<void> openReview(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    Future<void> Function()? extra,
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
    await addUnits(tester, 1, 2);
    await addUnits(tester, 2, 1);
    if (extra != null) await extra();
    await tester.tap(find.widgetWithText(FilledButton, 'Review request'));
    await tester.pumpAndSettle();
  }

  /// Taps "Authorize request" and lets both mock calls (600 ms each) finish.
  Future<void> authorize(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Authorize request'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  /// Lets the fake robot finish (1 unit per second) and the snackbar disappear,
  /// so no timers are left when the test ends.
  Future<void> letRobotFinish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  /// Orders as the API lists them (runs with real time, because the mock waits).
  Future<List<OrderStatus>> orderStatuses(WidgetTester tester) async {
    final orders = await tester.runAsync(() => api.listOrders());
    return [for (final o in orders!) o.status];
  }

  testWidgets('shows the patient, the requested items and the total', (tester) async {
    await openReview(tester);
    expect(find.text('Review your request'), findsOneWidget);
    expect(find.text('Confirm the patient and supplies before authorizing.'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Sterile gauze pads'), findsOneWidget);
    expect(find.text('Slot 1'), findsOneWidget);
    expect(find.text('2 units'), findsOneWidget);
    expect(find.text('Adhesive dressing'), findsOneWidget);
    expect(find.text('1 unit'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('3 units'), findsOneWidget);
  });

  group('slot label and quantity are separate texts with clear space between them', () {
    // 1280x720 is the tightest case (spacing at its 0.6 minimum); 1920x1080 the largest.
    for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await openReview(tester, size: size);

        // Where the quantity's letters actually start: the text is right-aligned inside
        // its fixed-width column, so subtract the drawn text width from the right edge.
        double glyphLeft(Finder text) =>
            tester.getRect(text).right - tester.renderObject<RenderParagraph>(text).textSize.width;

        for (final (slot, units) in [('Slot 1', '2 units'), ('Slot 2', '1 unit')]) {
          final slotFinder = find.text(slot);
          final unitsFinder = find.text(units);
          expect(slotFinder, findsOneWidget);
          expect(unitsFinder, findsOneWidget);
          final gap = glyphLeft(unitsFinder) - tester.getRect(slotFinder).right;
          expect(gap, greaterThanOrEqualTo(16), reason: '"$slot" and "$units" must not touch (gap: $gap px)');
        }

        // The quantity column has the same width and right edge in every row.
        final columns = tester.widgetList(find.byKey(const Key('review-units'))).length;
        expect(columns, 2);
        final rects = [for (var i = 0; i < columns; i++) tester.getRect(find.byKey(const Key('review-units')).at(i))];
        expect(rects[1].width, rects[0].width);
        expect(rects[1].right, rects[0].right);
      });
    }
  });

  testWidgets('"Edit items" goes back to Supplies with the request kept', (tester) async {
    await openReview(tester);
    await tester.tap(find.text('Edit items'));
    await tester.pumpAndSettle();
    expect(find.text('Your request'), findsOneWidget);
    expect(find.text('3 units'), findsOneWidget);
    expect(api.createCalls, 0);
  });

  testWidgets('"Authorize request" creates and approves the order, then starts a new request', (tester) async {
    await openReview(tester);
    await authorize(tester);

    expect(find.text('Order #1 approved. The status screen comes in a later step.'), findsOneWidget);
    expect(find.text('Which patient?'), findsOneWidget);
    expect(api.createCalls, 1);
    expect(api.approveCalls, 1);

    await letRobotFinish(tester);
    expect(await orderStatuses(tester), [OrderStatus.done]);

    // The request was cleared: Supplies starts empty for the next patient.
    await tapDigits(tester, '284913');
    await tester.tap(find.text('Find patient'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, select supplies'));
    await tester.pumpAndSettle();
    expect(find.text('Your request is empty'), findsOneWidget);
  });

  testWidgets('not enough stock (409) shows the reason and keeps the request', (tester) async {
    api.createError = const ApiException(409, 'Not enough stock for Sterile gauze pads');
    await openReview(tester);
    await authorize(tester);
    expect(find.text('Not enough stock for Sterile gauze pads. Edit items and try again.'), findsOneWidget);
    expect(find.text('Review your request'), findsOneWidget);
    expect(api.approveCalls, 0);
  });

  testWidgets('if approving fails, the retry approves the same order instead of creating a new one', (tester) async {
    api.approveFailures = 1;
    await openReview(tester);
    await authorize(tester);
    expect(find.text('Could not reach the server. Try again.'), findsOneWidget);
    expect(await orderStatuses(tester), [OrderStatus.pending]);

    await authorize(tester);
    expect(find.text('Which patient?'), findsOneWidget);
    expect(api.createCalls, 1);
    expect(api.approveCalls, 2);
    await letRobotFinish(tester);
    expect(await orderStatuses(tester), [OrderStatus.done]);
  });

  testWidgets('"Edit items" after a failed approval cancels the pending order', (tester) async {
    api.approveFailures = 1;
    await openReview(tester);
    await authorize(tester);
    await tester.tap(find.text('Edit items'));
    await tester.pumpAndSettle();
    expect(find.text('Your request'), findsOneWidget);
    expect(await orderStatuses(tester), [OrderStatus.cancelled]);
  });

  group('fits the window without scrolling (5 lines)', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    Future<void> addThreeMore(WidgetTester tester) async {
      await openCategory(tester, 'IV and injections');
      await addUnits(tester, 3, 1);
      await openCategory(tester, 'Gloves and protection');
      await addUnits(tester, 5, 4);
      await addUnits(tester, 6, 2);
    }

    /// All 5 lines are built and visible (the list does not need to scroll), and the
    /// buttons sit inside a card that reaches the bottom of the window.
    void expectFits(WidgetTester tester, Size size) {
      expect(find.byType(SingleChildScrollView), findsNothing);
      final list = tester.getRect(find.byKey(const Key('review-list')));
      final lastLine = tester.getRect(find.text('Procedure mask'));
      expect(lastLine.bottom, lessThanOrEqualTo(list.bottom));
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(of: find.byKey(const Key('review-list')), matching: find.byType(Scrollable)),
            )
            .position
            .maxScrollExtent,
        0,
      );
      final button = tester.getRect(find.widgetWithText(FilledButton, 'Authorize request'));
      expect(button.bottom, lessThanOrEqualTo(size.height));
      final card = tester.getRect(find.byKey(const Key('page-card')));
      expect(card.bottom, greaterThanOrEqualTo(size.height - 36));
    }

    for (final size in sizes) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await openReview(tester, size: size, extra: () => addThreeMore(tester));
        expect(find.text('10 units'), findsOneWidget);
        expectFits(tester, size);
      });
    }

    testWidgets('1280x720 with an error message', (tester) async {
      api.approveFailures = 1;
      const size = Size(1280, 720);
      await openReview(tester, size: size, extra: () => addThreeMore(tester));
      await authorize(tester);
      expect(find.text('Could not reach the server. Try again.'), findsOneWidget);
      expectFits(tester, size);
    });
  });
}
