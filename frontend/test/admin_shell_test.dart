import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:id_nurse/main.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/mock_api_service.dart';
import 'package:id_nurse/theme/app_colors.dart';
import 'package:id_nurse/widgets/admin_shell.dart';

/// Supervisor dashboard frame: sidebar navigation, header title, open-reports badge,
/// sign out, nurse access and fitting the window.
void main() {
  late MockApiService api;

  tearDown(() => api.dispose());

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// [count] FAILED orders by the nurse, each reported (real time, before the app starts).
  Future<void> seedReports(WidgetTester tester, int count) async {
    await tester.runAsync(() async {
      api.failPicksAfterUnits = 0;
      await api.login('48216', LoginMethod.scan);
      for (var i = 0; i < count; i++) {
        final order = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 1)]);
        await api.approveOrder(order.id);
        while (!(await api.getOrder(order.id)).status.isFinal) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await api.reportProblem(order.id);
      }
      api.signOut();
    });
  }

  /// Starts the app and signs in as the supervisor through "Admin sign in".
  Future<void> openDashboard(WidgetTester tester, {Size size = const Size(1280, 800)}) async {
    setSize(tester, size);
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

  String title(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('admin-title'))).data!;

  Color? navColor(WidgetTester tester, String path) => tester.widget<Material>(find.byKey(ValueKey('nav-$path'))).color;

  MockApiService fastApi() => MockApiService(networkDelay: Duration.zero, pickInterval: const Duration(milliseconds: 5));

  testWidgets('supervisor lands on Problem reports; every sidebar item opens its page', (tester) async {
    api = fastApi();
    await openDashboard(tester);
    expect(title(tester), 'Problem reports');
    expect(find.text('ID NURSE ADMIN'), findsOneWidget);
    expect(find.text('Elena Ruiz'), findsOneWidget);
    expect(find.text('Supervisor'), findsOneWidget);
    expect(navColor(tester, '/supervisor/problems'), AppColors.primary); // highlighted
    expect(find.text('Identify'), findsNothing); // no nurse step tracker

    for (final item in adminNavItems.skip(1)) {
      await tester.tap(find.byKey(ValueKey('nav-${item.path}')));
      await tester.pumpAndSettle();
      expect(title(tester), item.label);
      expect(navColor(tester, item.path), AppColors.primary);
      expect(navColor(tester, '/supervisor/problems'), Colors.transparent);
      expect(find.byKey(const Key('admin-card')), findsOneWidget);
      // Pages not built yet still show the placeholder.
      const built = {'/supervisor/stock'};
      expect(find.text('This page is added in the next step.'), built.contains(item.path) ? findsNothing : findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('nav-/supervisor/problems')));
    await tester.pumpAndSettle();
    expect(title(tester), 'Problem reports');
    expect(find.text('No open problem reports'), findsOneWidget);
  });

  testWidgets('the badge shows open reports and goes down after "Mark resolved"', (tester) async {
    api = fastApi();
    await seedReports(tester, 2);
    await openDashboard(tester);
    final badge = find.byKey(const Key('nav-badge'));
    expect(find.descendant(of: badge, matching: find.text('2')), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Mark resolved').first);
    await tester.pumpAndSettle();
    expect(find.descendant(of: badge, matching: find.text('1')), findsOneWidget);

    // The badge is also right on another page.
    await tester.tap(find.byKey(const ValueKey('nav-/supervisor/stock')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: badge, matching: find.text('1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-/supervisor/problems')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Mark resolved'));
    await tester.pumpAndSettle();
    expect(badge, findsNothing); // no badge at 0
  });

  testWidgets('"Sign out" in the sidebar goes back to the login screen', (tester) async {
    api = fastApi();
    await openDashboard(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Identify yourself'), findsOneWidget);
    // The service forgot the user too: the next call is "not signed in" (401).
    final status = await tester.runAsync(() async {
      try {
        await api.me();
        return null;
      } on ApiException catch (e) {
        return e.statusCode;
      }
    });
    expect(status, 401);
  });

  testWidgets('/supervisor opens Problem reports', (tester) async {
    api = fastApi();
    await openDashboard(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/supervisor/log')));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byKey(const Key('admin-title')))).go('/supervisor');
    await tester.pumpAndSettle();
    expect(title(tester), 'Problem reports');
  });

  testWidgets('a nurse cannot open any dashboard page', (tester) async {
    api = fastApi();
    setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(IdNurseApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate card scan'));
    await tester.pumpAndSettle();
    for (final path in ['/supervisor', ...adminNavItems.map((i) => i.path)]) {
      GoRouter.of(tester.element(find.text('Which patient?'))).go(path);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-title')), findsNothing, reason: path);
      expect(find.text('Which patient?'), findsOneWidget, reason: path);
    }
  });

  group('fits the window without scrolling', () {
    const sizes = [Size(1280, 720), Size(1366, 768), Size(1280, 800), Size(1920, 1080)];

    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets(label, (tester) async {
        api = fastApi();
        await seedReports(tester, 5);
        await openDashboard(tester, size: size);
        expect(find.byType(SingleChildScrollView), findsNothing);
        // 220 px sidebar up to 1250 px wide, 250 px above (like the prototype).
        final sidebar = tester.getRect(find.byKey(const ValueKey('nav-/supervisor/problems')));
        expect(sidebar.width, size.width <= 1250 ? 220 - 32 : 250 - 32); // minus the sidebar padding
        expect(tester.getRect(find.widgetWithText(OutlinedButton, 'Sign out')).bottom, lessThanOrEqualTo(size.height));
        final card = tester.getRect(find.byKey(const Key('admin-card')));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        expect(tester.getRect(find.byKey(const Key('report-list'))).bottom, lessThanOrEqualTo(card.bottom));
        final list = find.descendant(of: find.byKey(const Key('report-list')), matching: find.byType(Scrollable));
        expect(tester.state<ScrollableState>(list.first).position.maxScrollExtent, 0);
      });
    }
  });
}
