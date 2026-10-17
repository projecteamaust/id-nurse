import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/mock_api_service.dart';

/// Supervisor dashboard "Low stock": items at or below their minimum, the sidebar badge,
/// and refilling from the page.
void main() {
  late MockApiService api;

  tearDown(() => api.dispose());

  Future<void> signIn(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdNurseApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('supervisor-id')), '31082');
    await tester.enterText(find.byKey(const Key('supervisor-password')), MockApiService.demoSupervisorPassword);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  Future<void> openPage(WidgetTester tester, String path) async {
    await tester.tap(find.byKey(ValueKey('nav-$path')));
    await tester.pumpAndSettle();
  }

  /// The Low stock badge number, or null when there is no badge.
  String? badge(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byKey(const ValueKey('nav-badge-/supervisor/low-stock')),
      matching: find.byType(Text),
    );
    return finder.evaluate().isEmpty ? null : tester.widget<Text>(finder).data;
  }

  Future<void> editQuantity(WidgetTester tester, int itemId, String quantity) async {
    await tester.tap(find.byKey(ValueKey('edit-$itemId')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('stock-quantity')), quantity);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists items at or below their minimum, lowest first, with units to the minimum', (tester) async {
    api = MockApiService(networkDelay: Duration.zero);
    await signIn(tester);
    expect(badge(tester), '2'); // syringe (0) and dressing (9 of 10), loaded with the dashboard
    await openPage(tester, '/supervisor/low-stock');

    for (final header in ['QUANTITY', 'MINIMUM', 'TO MINIMUM', 'STATUS']) {
      expect(find.text(header), findsOneWidget);
    }
    // Lowest first: the syringe row is above the dressing row.
    expect(tester.getRect(find.byKey(const ValueKey('low-4'))).top,
        lessThan(tester.getRect(find.byKey(const ValueKey('low-2'))).top));
    expect(tester.widget<Text>(find.byKey(const ValueKey('to-min-4'))).data, '+10');
    expect(tester.widget<Text>(find.byKey(const ValueKey('to-min-2'))).data, '+1');
    final table = find.byKey(const Key('low-stock-table'));
    expect(find.descendant(of: table, matching: find.text('Empty')), findsOneWidget);
    expect(find.descendant(of: table, matching: find.text('Low')), findsOneWidget);
    expect(find.descendant(of: table, matching: find.text('Sterile gauze pads')), findsNothing); // 42: not low
  });

  testWidgets('refilling an item removes it from the list and lowers the badge', (tester) async {
    api = MockApiService(networkDelay: Duration.zero);
    await signIn(tester);
    await openPage(tester, '/supervisor/low-stock');
    await editQuantity(tester, 2, '20'); // dressing above its minimum
    expect(find.byKey(const ValueKey('low-2')), findsNothing);
    expect(find.byKey(const ValueKey('low-4')), findsOneWidget);
    expect(badge(tester), '1');
    expect(find.text('Stock updated: Adhesive dressing, 20 units.'), findsOneWidget);

    await editQuantity(tester, 4, '10'); // syringe exactly at its minimum: still low
    expect(tester.widget<Text>(find.byKey(const ValueKey('to-min-4'))).data, 'At minimum');
    expect(badge(tester), '1');

    await editQuantity(tester, 4, '50');
    expect(find.text('No items are low on stock.'), findsOneWidget);
    expect(badge(tester), isNull);
  });

  testWidgets('an edit on the Stock page also updates the badge', (tester) async {
    api = MockApiService(networkDelay: Duration.zero);
    await signIn(tester);
    await openPage(tester, '/supervisor/stock');
    await editQuantity(tester, 1, '3'); // gauze becomes low
    expect(badge(tester), '3');
    await openPage(tester, '/supervisor/low-stock');
    expect(find.byKey(const ValueKey('low-1')), findsOneWidget);
  });

  group('fits the window without scrolling', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('$label with all 6 items low', (tester) async {
        api = MockApiService(networkDelay: Duration.zero);
        await tester.runAsync(() async {
          await api.login('31082', LoginMethod.manual, password: MockApiService.demoSupervisorPassword);
          for (var id = 1; id <= 6; id++) {
            await api.updateItemQuantity(id, id); // every item below its minimum
          }
          api.signOut();
        });
        await signIn(tester, size: size);
        await openPage(tester, '/supervisor/low-stock');
        expect(find.byType(SingleChildScrollView), findsNothing);
        final card = tester.getRect(find.byKey(const Key('admin-card')));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        final table = find.byKey(const Key('low-stock-table'));
        expect(tester.getRect(table).bottom, lessThanOrEqualTo(card.bottom));
        final body = find.descendant(of: table, matching: find.byType(Scrollable));
        expect(tester.state<ScrollableState>(body.first).position.maxScrollExtent, 0);
      });
    }
  });
}
