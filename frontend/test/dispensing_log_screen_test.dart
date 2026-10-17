import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/mock_api_service.dart';
import 'package:intl/intl.dart';

/// Supervisor dashboard "Dispensing log": Orders and Actions tables with the date and
/// nurse filters.
void main() {
  late MockApiService api;

  // The mock's clock: seeding moves it to other days, then it is "now" again.
  final today = DateUtils.dateOnly(DateTime.now());
  final twoDaysAgo = today.subtract(const Duration(days: 2));
  late DateTime now;

  setUp(() {
    now = DateTime.now();
    api = MockApiService(networkDelay: Duration.zero, pickInterval: const Duration(milliseconds: 5), clock: () => now);
  });

  tearDown(() => api.dispose());

  Future<void> waitUntilFinal(int orderId) async {
    while (!(await api.getOrder(orderId)).status.isFinal) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Order #1: the nurse, two days ago, DONE. Order #2: the nurse, today, DONE.
  /// Order #3: the supervisor, today, still PENDING.
  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      await api.login('48216', LoginMethod.scan);
      now = twoDaysAgo.add(const Duration(hours: 10));
      final old = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 2)]);
      await api.approveOrder(old.id);
      await waitUntilFinal(old.id);
      now = DateTime.now();
      final recent = await api.createOrder('548220', const [OrderLineRequest(itemId: 5, qty: 1)]);
      await api.approveOrder(recent.id);
      await waitUntilFinal(recent.id);
      await api.login('31082', LoginMethod.manual, password: MockApiService.demoSupervisorPassword);
      await api.createOrder('284913', const [OrderLineRequest(itemId: 2, qty: 1)]);
      api.signOut();
    });
  }

  Future<void> openLog(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
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
    await tester.tap(find.byKey(const ValueKey('nav-/supervisor/log')));
    await tester.pumpAndSettle();
  }

  Finder inTable(String key, Finder finder) => find.descendant(of: find.byKey(Key(key)), matching: finder);

  /// Order numbers in the Orders table, top to bottom.
  List<String> orderNumbers(WidgetTester tester) => tester
      .widgetList<Text>(inTable('log-orders-table', find.textContaining(RegExp(r'^#\d+$'))))
      .map((t) => t.data!)
      .toList();

  /// Picks a day in the date picker by typing it (works whatever month the calendar opens on).
  Future<void> pickDay(WidgetTester tester, Key button, DateTime day) async {
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        DateFormat.yMd().format(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseNurse(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('filter-nurse')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Orders: newest first with patient, nurse, items, units and status', (tester) async {
    await seed(tester);
    await openLog(tester);
    for (final header in ['DATE AND TIME', 'ORDER', 'PATIENT', 'NURSE', 'ITEMS', 'UNITS', 'STATUS']) {
      expect(find.text(header), findsOneWidget);
    }
    expect(orderNumbers(tester), ['#3', '#2', '#1']);
    expect(inTable('log-orders-table', find.text('Done')), findsNWidgets(2));
    expect(inTable('log-orders-table', find.text('Pending')), findsOneWidget);
    expect(inTable('log-orders-table', find.text('Elena Ruiz')), findsOneWidget);
    expect(inTable('log-orders-table', find.text('548220')), findsOneWidget);
  });

  testWidgets('Actions: who did what, with "System" for the robot', (tester) async {
    await seed(tester);
    await openLog(tester);
    await tester.tap(find.byKey(const Key('tab-actions')));
    await tester.pumpAndSettle();
    for (final header in ['TIME', 'WHO', 'ACTION', 'SUMMARY']) {
      expect(find.text(header), findsOneWidget);
    }
    expect(inTable('log-actions-table', find.text('Picked 1 × Sterile gauze pads (slot 1)')), findsNWidgets(2));
    expect(inTable('log-actions-table', find.text('System')), findsWidgets);
    expect(inTable('log-actions-table', find.text('Order approved')), findsNWidgets(2));
    expect(inTable('log-actions-table', find.text('Approved order #1')), findsOneWidget);
    expect(inTable('log-actions-table', find.text('Elena Ruiz signed in (employee ID)')), findsWidgets);
  });

  testWidgets('the nurse filter keeps that nurse\'s orders and actions; Clear filters shows all', (tester) async {
    await seed(tester);
    await openLog(tester);
    await chooseNurse(tester, 'Maya Chen');
    expect(orderNumbers(tester), ['#2', '#1']);

    await tester.tap(find.byKey(const Key('tab-actions')));
    await tester.pumpAndSettle();
    expect(inTable('log-actions-table', find.text('System')), findsNothing); // only what she did
    expect(inTable('log-actions-table', find.text('Elena Ruiz')), findsNothing);
    expect(inTable('log-actions-table', find.text('Maya Chen')), findsWidgets);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(inTable('log-actions-table', find.text('System')), findsWidgets);
    await tester.tap(find.byKey(const Key('tab-orders')));
    await tester.pumpAndSettle();
    expect(orderNumbers(tester), ['#3', '#2', '#1']);
  });

  testWidgets('From and To keep only the chosen days (inclusive)', (tester) async {
    await seed(tester);
    await openLog(tester);
    await pickDay(tester, const Key('filter-from'), today);
    expect(find.text('From: ${DateFormat.yMMMd().format(today)}'), findsOneWidget);
    expect(orderNumbers(tester), ['#3', '#2']);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await pickDay(tester, const Key('filter-to'), twoDaysAgo);
    expect(orderNumbers(tester), ['#1']);

    await pickDay(tester, const Key('filter-from'), twoDaysAgo); // the same day on both ends
    expect(orderNumbers(tester), ['#1']);

    await tester.tap(find.byKey(const Key('tab-actions')));
    await tester.pumpAndSettle();
    expect(inTable('log-actions-table', find.text('Approved order #1')), findsOneWidget);
    expect(inTable('log-actions-table', find.text('Approved order #2')), findsNothing);
  });

  testWidgets('an empty result says so', (tester) async {
    await seed(tester);
    await openLog(tester);
    await pickDay(tester, const Key('filter-to'), today.subtract(const Duration(days: 10)));
    expect(find.text('No orders match these filters.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-actions')));
    await tester.pumpAndSettle();
    expect(find.text('No actions match these filters.'), findsOneWidget);
  });

  group('fits the window; only the table scrolls', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets(label, (tester) async {
        await tester.runAsync(() async {
          await api.login('48216', LoginMethod.scan);
          for (var i = 0; i < 40; i++) {
            await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 1)]);
          }
          api.signOut();
        });
        await openLog(tester, size: size);
        expect(find.byType(SingleChildScrollView), findsNothing);
        final card = tester.getRect(find.byKey(const Key('admin-card')));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        for (final tab in ['tab-orders', 'tab-actions']) {
          await tester.tap(find.byKey(Key(tab)));
          await tester.pumpAndSettle();
          final table = find.byKey(Key(tab == 'tab-orders' ? 'log-orders-table' : 'log-actions-table'));
          expect(tester.getRect(table).bottom, lessThanOrEqualTo(card.bottom), reason: tab);
          // More rows than fit: the table scrolls inside its own box.
          final body = find.descendant(of: table, matching: find.byType(Scrollable));
          expect(tester.state<ScrollableState>(body.first).position.maxScrollExtent, greaterThan(0), reason: tab);
        }
      });
    }
  });
}
