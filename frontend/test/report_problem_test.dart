import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/models/order.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/mock_api_service.dart';

/// "Report problem" (Collect for PARTIAL, the FAILED result), supervisor sign in and
/// the supervisor dashboard's "Problem reports" with "Mark resolved".
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

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Nurse card login, patient 284913, gauze ×2 + dressing ×1 unless [lines] adds others,
  /// authorize, and wait until the robot is done ([until] shows up).
  Future<void> runOrder(WidgetTester tester, Finder until, {Future<void> Function()? lines}) async {
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
    await pumpUntilFound(tester, until);
  }

  /// PARTIAL order (the dressing is missing), then "Collect available items".
  Future<void> openPartialCollect(WidgetTester tester, {Future<void> Function()? lines}) async {
    await runOrder(tester, find.text('Collect available items'), lines: lines);
    await tester.tap(find.text('Collect available items'));
    await tester.pumpAndSettle();
  }

  Future<void> sendReport(WidgetTester tester, {String note = ''}) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Report problem'));
    await tester.pumpAndSettle();
    if (note.isNotEmpty) await tester.enterText(find.byKey(const Key('report-note')), note);
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
  }

  /// Sign out, "Admin sign in", supervisor ID + password.
  Future<void> signInSupervisor(WidgetTester tester, {String password = MockApiService.demoSupervisorPassword}) async {
    if (find.text('Sign out').evaluate().isNotEmpty) {
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Admin sign in'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('supervisor-id')), '31082');
    await tester.enterText(find.byKey(const Key('supervisor-password')), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }

  group('nurse: Report problem', () {
    testWidgets('Collect (PARTIAL): the warning names what is missing; send a report with a note', (tester) async {
      api = MockApiService()..failPicksAfterUnits = 2;
      setSize(tester, const Size(1280, 800));
      await openPartialCollect(tester);
      expect(find.text('Not dispensed: Adhesive dressing ×1. Please report the problem to your supervisor.'),
          findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Report problem'));
      await tester.pumpAndSettle();
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.text('Order #1 · Not dispensed: Adhesive dressing ×1'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('report-note')), 'Drawer 2 looked jammed');
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();

      expect(find.text('Report a problem'), findsNothing); // dialog closed
      expect(find.text('Problem reported'), findsOneWidget);
      expect(find.text('Problem reported to your supervisor. Not dispensed: Adhesive dressing ×1.'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Problem reported')).onPressed,
          isNull);

      // Direct service calls need real time (the mock's network delay is a real timer).
      final report = (await tester.runAsync(() async {
        await api.login('31082', LoginMethod.manual, password: MockApiService.demoSupervisorPassword);
        return api.listProblemReports();
      }))!
          .single;
      expect(report.note, 'Drawer 2 looked jammed');
      expect(report.nurse.name, 'Maya Chen');
      expect(report.missingItems.single.name, 'Adhesive dressing');
    });

    testWidgets('FAILED result: report without a note, then start a new request', (tester) async {
      api = MockApiService()..failPicksAfterUnits = 0;
      setSize(tester, const Size(1280, 800));
      await runOrder(tester, find.text('Your request could not be dispensed'));
      expect(
        find.text('Not dispensed: Sterile gauze pads ×2, Adhesive dressing ×1. '
            'Please report the problem to your supervisor.'),
        findsOneWidget,
      );
      await sendReport(tester);
      expect(find.text('Problem reported'), findsOneWidget);

      await tester.tap(find.text('Start a new request'));
      await tester.pumpAndSettle();
      expect(find.text('Which patient?'), findsOneWidget);
    });

    testWidgets('Cancel closes the dialog and sends nothing', (tester) async {
      api = MockApiService()..failPicksAfterUnits = 2;
      setSize(tester, const Size(1280, 800));
      await openPartialCollect(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Report problem'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Report a problem'), findsNothing);
      expect(find.text('Report problem'), findsOneWidget);
      final reports = await tester.runAsync(() async {
        await api.login('31082', LoginMethod.manual, password: MockApiService.demoSupervisorPassword);
        return api.listProblemReports();
      });
      expect(reports, isEmpty);
    });

    testWidgets('an order that already has an open report shows as reported (409)', (tester) async {
      api = MockApiService()..failPicksAfterUnits = 2;
      setSize(tester, const Size(1280, 800));
      await openPartialCollect(tester);
      await tester.runAsync(() => api.reportProblem(1)); // e.g. sent before from another screen
      await sendReport(tester);
      expect(find.text('Problem reported'), findsOneWidget);
    });

    testWidgets('a note over 200 characters cannot be typed', (tester) async {
      api = MockApiService()..failPicksAfterUnits = 2;
      setSize(tester, const Size(1280, 800));
      await openPartialCollect(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Report problem'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report-note')), 'x' * 250);
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('report-note'))).controller!.text, hasLength(200));
    });
  });

  group('supervisor', () {
    testWidgets('sees the report, marks it resolved, and the list is empty', (tester) async {
      api = MockApiService()..failPicksAfterUnits = 2;
      setSize(tester, const Size(1280, 800));
      await openPartialCollect(tester);
      await sendReport(tester, note: 'Drawer 2 looked jammed');

      await signInSupervisor(tester);
      expect(find.text('Problem reports'), findsOneWidget);
      expect(find.text('1 open'), findsOneWidget);
      expect(find.textContaining('Order #1 · Maya Chen · '), findsOneWidget);
      expect(find.text('Not dispensed: Adhesive dressing ×1'), findsOneWidget);
      expect(find.text('“Drawer 2 looked jammed”'), findsOneWidget);
      expect(find.text('Identify'), findsNothing); // no nurse step tracker

      await tester.tap(find.widgetWithText(OutlinedButton, 'Mark resolved'));
      await tester.pumpAndSettle();
      expect(find.text('No open problem reports'), findsOneWidget);
      expect(find.text('0 open'), findsOneWidget);
      expect(await tester.runAsync(() => api.listProblemReports()), isEmpty);
    });

    testWidgets('wrong password or a nurse ID is refused on Supervisor sign in', (tester) async {
      api = MockApiService();
      setSize(tester, const Size(1280, 800));
      await tester.pumpWidget(IdNurseApp(api: api));
      await tester.pumpAndSettle();
      await signInSupervisor(tester, password: 'nope');
      expect(find.text('Wrong employee ID or password.'), findsOneWidget);
      expect(find.text('Supervisor sign in'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('supervisor-id')), '48216'); // the nurse
      await tester.enterText(find.byKey(const Key('supervisor-password')), 'anything');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('This sign in is for supervisors. Nurses sign in with their card.'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Identify yourself'), findsOneWidget);
    });

    testWidgets('a nurse cannot open the dashboard', (tester) async {
      api = MockApiService();
      setSize(tester, const Size(1280, 800));
      await tester.pumpWidget(IdNurseApp(api: api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate card scan'));
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('Which patient?'))).go('/supervisor');
      await tester.pumpAndSettle();
      expect(find.text('Problem reports'), findsNothing);
      expect(find.text('Which patient?'), findsOneWidget);
    });
  });

  group('fits the window without scrolling', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    Future<void> fiveLines(WidgetTester tester) async {
      await addUnits(tester, 1, 2);
      await addUnits(tester, 2, 1);
      await openCategory(tester, 'IV and injections');
      await addUnits(tester, 3, 1);
      await openCategory(tester, 'Gloves and protection');
      await addUnits(tester, 5, 4);
      await addUnits(tester, 6, 2);
    }

    void expectInCard(WidgetTester tester, Size size, Finder finder) {
      expect(find.byType(SingleChildScrollView), findsNothing);
      final card = tester.getRect(find.byKey(const Key('page-card')));
      expect(card.bottom, lessThanOrEqualTo(size.height));
      expect(tester.getRect(finder).bottom, lessThanOrEqualTo(card.bottom));
    }

    void expectListFits(WidgetTester tester, Key key) {
      final scrollable = find.descendant(of: find.byKey(key), matching: find.byType(Scrollable));
      expect(tester.state<ScrollableState>(scrollable.first).position.maxScrollExtent, 0);
    }

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('$label FAILED with 5 rows and the report panel', (tester) async {
        api = MockApiService()..failPicksAfterUnits = 0;
        setSize(tester, size);
        await runOrder(tester, find.text('Your request could not be dispensed'), lines: () => fiveLines(tester));
        expectInCard(tester, size, find.widgetWithText(FilledButton, 'Start a new request'));
        expectInCard(tester, size, find.widgetWithText(OutlinedButton, 'Report problem'));
        expectListFits(tester, const Key('result-list'));
      });

      testWidgets('$label Collect (PARTIAL, 5 lines): report panel and the dialog fit', (tester) async {
        api = MockApiService()..failPicksAfterUnits = 8; // the masks are not dispensed
        setSize(tester, size);
        await openPartialCollect(tester, lines: () => fiveLines(tester));
        expectInCard(tester, size, find.widgetWithText(OutlinedButton, 'Report problem'));
        expectInCard(tester, size, find.widgetWithText(FilledButton, 'I have collected my items'));
        expectListFits(tester, const Key('collect-list'));

        await tester.tap(find.widgetWithText(OutlinedButton, 'Report problem'));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.widgetWithText(FilledButton, 'Send')).bottom, lessThanOrEqualTo(size.height));
      });

      testWidgets('$label dashboard with 5 reports', (tester) async {
        api = MockApiService(networkDelay: Duration.zero, pickInterval: const Duration(milliseconds: 5))
          ..failPicksAfterUnits = 0;
        setSize(tester, size);
        // Five FAILED orders, each reported with a note (real time, before the app starts).
        await tester.runAsync(() async {
          await api.login('48216', LoginMethod.scan);
          for (var i = 0; i < 5; i++) {
            final order = await api.createOrder('284913', const [
              OrderLineRequest(itemId: 1, qty: 2),
              OrderLineRequest(itemId: 5, qty: 4),
            ]);
            await api.approveOrder(order.id);
            while (!(await api.getOrder(order.id)).status.isFinal) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
            expect((await api.getOrder(order.id)).status, OrderStatus.failed);
            await api.reportProblem(order.id, note: 'Robot stopped before the first pick, order ${order.id}');
          }
          api.signOut();
        });
        await tester.pumpWidget(IdNurseApp(api: api));
        await tester.pumpAndSettle();
        await signInSupervisor(tester);
        expect(find.text('5 open'), findsOneWidget);
        expectInCard(tester, size, find.byKey(const Key('report-list')));
        expectListFits(tester, const Key('report-list'));
      });
    }
  });
}
