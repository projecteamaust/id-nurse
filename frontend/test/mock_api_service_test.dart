import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/models/order.dart';
import 'package:id_nurse/models/problem_report.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/mock_api_service.dart';

/// Matches an ApiException with the given status code.
Matcher _apiError(int code) =>
    throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', code));

void main() {
  late MockApiService api;

  setUp(() {
    // No network delay and a fast robot so the tests run quickly.
    api = MockApiService(networkDelay: Duration.zero, pickInterval: const Duration(milliseconds: 5));
  });

  tearDown(() => api.dispose());

  Future<void> signInNurse() => api.login('48216', LoginMethod.manual);

  /// Polls the order like the status screen does, until it reaches a final state.
  Future<Order> waitUntilFinal(int orderId) async {
    for (var i = 0; i < 400; i++) {
      final order = await api.getOrder(orderId);
      if (order.status.isFinal) return order;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Order $orderId never reached a final state');
  }

  group('login', () {
    test('nurse signs in with ID only', () async {
      final res = await api.login('48216', LoginMethod.scan);
      expect(res.tokenType, 'bearer');
      expect(res.expiresIn, 28800);
      expect(res.user.role, 'nurse');
      expect(res.user.ward, 'Ward 4 · Surgical');
      expect((await api.me()).employeeId, '48216');
    });

    test('unknown employee ID gives 401 "No staff ID found"', () async {
      await expectLater(
        api.login('99999', LoginMethod.manual),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.detail, 'detail', 'No staff ID found')),
      );
    });

    test('supervisor needs the password', () async {
      await expectLater(api.login('31082', LoginMethod.manual), _apiError(401));
      await expectLater(api.login('31082', LoginMethod.manual, password: 'wrong'), _apiError(401));
      final res = await api.login('31082', LoginMethod.manual,
          password: MockApiService.demoSupervisorPassword);
      expect(res.user.isSupervisor, isTrue);
    });

    test('calls need a signed-in user; sign out forgets it', () async {
      await expectLater(api.getItems(), _apiError(401));
      await signInNurse();
      api.signOut();
      await expectLater(api.me(), _apiError(401));
    });
  });

  group('patients and items', () {
    setUp(signInNurse);

    test('known patient is returned, unknown gives 404', () async {
      expect((await api.getPatient('284913')).name, 'Alex Morgan');
      await expectLater(api.getPatient('000000'), _apiError(404));
    });

    test('items have categories, low_stock and filters', () async {
      final all = await api.getItems();
      expect(all, hasLength(6));
      expect(all.map((i) => i.slotNumber), [1, 2, 3, 4, 5, 6]);
      expect(all.firstWhere((i) => i.id == 2).lowStock, isTrue); // 9 <= 10
      expect(all.firstWhere((i) => i.id == 4).outOfStock, isTrue);
      expect(await api.getItems(category: 'Wound care'), hasLength(2));
      expect((await api.getItems(search: 'GAUZE')).single.name, 'Sterile gauze pads');
    });
  });

  group('orders', () {
    setUp(signInNurse);

    test('validation: 422 for bad quantities, 404 patient, 409 stock', () async {
      await expectLater(api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 0)]), _apiError(422));
      await expectLater(api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 31)]), _apiError(422));
      await expectLater(api.createOrder('000000', const [OrderLineRequest(itemId: 1, qty: 1)]), _apiError(404));
      await expectLater(api.createOrder('284913', const [OrderLineRequest(itemId: 4, qty: 1)]), _apiError(409));
    });

    test('new order is PENDING and stock does not change yet', () async {
      final order = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 3)]);
      expect(order.status, OrderStatus.pending);
      expect(order.approvedAt, isNull);
      expect(order.nurse.employeeId, '48216');
      expect(order.items.single.qtyDispensed, 0);
      expect((await api.getItems(search: 'gauze')).single.quantity, 42);
    });

    test('approved order goes DISPENSING -> DONE and stock goes down', () async {
      final created = await api.createOrder('284913', const [
        OrderLineRequest(itemId: 1, qty: 3),
        OrderLineRequest(itemId: 5, qty: 2),
      ]);
      final approved = await api.approveOrder(created.id);
      expect(approved.status, OrderStatus.dispensing);
      expect(approved.approvedAt, isNotNull);

      final done = await waitUntilFinal(created.id);
      expect(done.status, OrderStatus.done);
      expect(done.completedAt, matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$')));
      expect(done.items.every((l) => l.qtyDispensed == l.qtyRequested), isTrue);
      expect((await api.getItems(search: 'gauze')).single.quantity, 39);
    });

    test('order ends PARTIAL when a drawer runs empty', () async {
      // Two orders together want 9 + 1 units of an item with only 9 in stock.
      // The empty item is last, so the mask is picked first.
      final first = await api.createOrder('284913', const [OrderLineRequest(itemId: 2, qty: 9)]);
      final second = await api.createOrder('284913', const [
        OrderLineRequest(itemId: 6, qty: 1),
        OrderLineRequest(itemId: 2, qty: 1),
      ]);
      await api.approveOrder(first.id);
      expect((await waitUntilFinal(first.id)).status, OrderStatus.done);
      await api.approveOrder(second.id);
      final result = await waitUntilFinal(second.id);
      expect(result.status, OrderStatus.partial);
      expect(result.items.where((l) => l.qtyDispensed < l.qtyRequested).single.itemId, 2);
    });

    test('a failed pick is retried once, then the whole order stops', () async {
      // The empty drawer comes first: after one retry the order stops, so the mask
      // (second line) is never picked and nothing was dispensed -> FAILED.
      // Both orders are created while stock is still there; the first one then empties it.
      final first = await api.createOrder('284913', const [OrderLineRequest(itemId: 2, qty: 9)]);
      final second = await api.createOrder('284913', const [
        OrderLineRequest(itemId: 2, qty: 1),
        OrderLineRequest(itemId: 6, qty: 1),
      ]);
      await api.approveOrder(first.id);
      await waitUntilFinal(first.id);
      await api.approveOrder(second.id);
      final result = await waitUntilFinal(second.id);
      expect(result.status, OrderStatus.failed);
      expect(result.items.every((l) => l.qtyDispensed == 0), isTrue);
      expect((await api.getItems(search: 'mask')).single.quantity, 26); // untouched
    });

    test('tests can force FAILED: the arm faults from the first pick', () async {
      api.failPicksAfterUnits = 0;
      final order = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 2)]);
      await api.approveOrder(order.id);
      final result = await waitUntilFinal(order.id);
      expect(result.status, OrderStatus.failed);
      expect(result.completedAt, isNotNull);
      expect((await api.getItems(search: 'gauze')).single.quantity, 42); // no pick, no stock change
    });

    test('tests can force PARTIAL: the arm faults after 2 units', () async {
      api.failPicksAfterUnits = 2;
      final order = await api.createOrder('284913', const [
        OrderLineRequest(itemId: 1, qty: 2),
        OrderLineRequest(itemId: 2, qty: 1),
      ]);
      await api.approveOrder(order.id);
      final result = await waitUntilFinal(order.id);
      expect(result.status, OrderStatus.partial);
      expect([for (final l in result.items) l.qtyDispensed], [2, 0]);
      expect((await api.getItems(search: 'gauze')).single.quantity, 40); // only picked units
      expect((await api.getItems(search: 'adhesive')).single.quantity, 9);
    });

    test('approve and cancel only while PENDING (409 otherwise)', () async {
      final order = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 1)]);
      expect((await api.cancelOrder(order.id)).status, OrderStatus.cancelled);
      await expectLater(api.approveOrder(order.id), _apiError(409));
      await expectLater(api.cancelOrder(order.id), _apiError(409));
    });

    test('a nurse cannot approve another nurse\'s order (403)', () async {
      await api.login('31082', LoginMethod.manual, password: MockApiService.demoSupervisorPassword);
      final supervisorOrder = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 1)]);
      await signInNurse();
      await expectLater(api.approveOrder(supervisorOrder.id), _apiError(403));
    });

    test('listOrders is newest first with counts', () async {
      await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 3)]);
      await api.createOrder('548220', const [
        OrderLineRequest(itemId: 1, qty: 2),
        OrderLineRequest(itemId: 5, qty: 5),
      ]);
      final list = await api.listOrders();
      expect(list.map((o) => o.patientFileNumber), ['548220', '284913']);
      expect(list.first.itemCount, 2);
      expect(list.first.totalUnits, 7);
      expect(list.first.nurseName, 'Maya Chen');
      expect(await api.listOrders(limit: 1), hasLength(1));
    });
  });

  group('stock edit (PATCH /items/{id})', () {
    Future<void> signInSupervisor() =>
        api.login('31082', LoginMethod.manual, password: MockApiService.demoSupervisorPassword);

    test('supervisor sets the quantity; low_stock is recalculated; GET /items shows it', () async {
      await signInSupervisor();
      final item = await api.updateItemQuantity(1, 5); // gauze: minimum 10
      expect(item.quantity, 5);
      expect(item.lowStock, isTrue);
      expect((await api.getItems(search: 'gauze')).single.quantity, 5);
      expect((await api.updateItemQuantity(1, 11)).lowStock, isFalse);
      expect((await api.updateItemQuantity(4, 0)).outOfStock, isTrue);
    });

    test('0 to 999 only (422); unknown item 404; nurse 403', () async {
      await signInSupervisor();
      await expectLater(api.updateItemQuantity(1, -1), _apiError(422));
      await expectLater(api.updateItemQuantity(1, 1000), _apiError(422));
      expect((await api.updateItemQuantity(1, 999)).quantity, 999);
      await expectLater(api.updateItemQuantity(99, 5), _apiError(404));
      await signInNurse();
      await expectLater(api.updateItemQuantity(1, 5), _apiError(403));
    });
  });

  group('problem reports', () {
    Future<void> signInSupervisor() =>
        api.login('31082', LoginMethod.manual, password: MockApiService.demoSupervisorPassword);

    /// A PARTIAL order of the signed-in user: 2 gauze picked, 1 dressing missing.
    Future<Order> partialOrder() async {
      api.failPicksAfterUnits = 2;
      final order = await api.createOrder('284913', const [
        OrderLineRequest(itemId: 1, qty: 2),
        OrderLineRequest(itemId: 2, qty: 1),
      ]);
      await api.approveOrder(order.id);
      return waitUntilFinal(order.id);
    }

    setUp(signInNurse);

    test('a report lists the missing items, the nurse and the note; status is open', () async {
      final order = await partialOrder();
      final report = await api.reportProblem(order.id, note: '  Drawer 2 looked jammed  ');
      expect(report.orderId, order.id);
      expect(report.status, ReportStatus.open);
      expect(report.note, 'Drawer 2 looked jammed');
      expect(report.nurse.employeeId, '48216');
      expect(report.missingItems.map((m) => (m.name, m.qtyMissing)), [('Adhesive dressing', 1)]);
      expect(report.resolvedAt, isNull);
      expect(report.resolvedBy, isNull);
    });

    test('the note is optional; empty means null; over 200 characters gives 422', () async {
      final order = await partialOrder();
      await expectLater(api.reportProblem(order.id, note: 'x' * 201), _apiError(422));
      expect((await api.reportProblem(order.id, note: '   ')).note, isNull);
    });

    test('a FAILED order lists every line as missing', () async {
      api.failPicksAfterUnits = 0;
      final order = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 3)]);
      await api.approveOrder(order.id);
      await waitUntilFinal(order.id);
      final report = await api.reportProblem(order.id);
      expect(report.missingItems.single.qtyMissing, 3);
    });

    test('only PARTIAL or FAILED orders can be reported (409)', () async {
      final order = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 1)]);
      await expectLater(api.reportProblem(order.id), _apiError(409)); // PENDING
      await api.approveOrder(order.id);
      await waitUntilFinal(order.id); // DONE
      await expectLater(api.reportProblem(order.id), _apiError(409));
      await expectLater(api.reportProblem(999), _apiError(404));
    });

    test('one open report per order (409); a new one is allowed once it is resolved', () async {
      final order = await partialOrder();
      final first = await api.reportProblem(order.id);
      await expectLater(api.reportProblem(order.id), _apiError(409));
      await signInSupervisor();
      await api.resolveProblemReport(first.id);
      await signInNurse();
      expect((await api.reportProblem(order.id)).status, ReportStatus.open);
    });

    test('a nurse cannot report another nurse\'s order (403)', () async {
      await signInSupervisor();
      final order = await partialOrder();
      await signInNurse();
      await expectLater(api.reportProblem(order.id), _apiError(403));
    });

    test('listing and resolving are for supervisors only (403)', () async {
      final report = await api.reportProblem((await partialOrder()).id);
      await expectLater(api.listProblemReports(), _apiError(403));
      await expectLater(api.resolveProblemReport(report.id), _apiError(403));
    });

    test('supervisor lists open reports newest first, resolves one; it leaves the open list', () async {
      final first = await api.reportProblem((await partialOrder()).id, note: 'first');
      final second = await api.reportProblem((await partialOrder()).id, note: 'second');
      await signInSupervisor();
      expect((await api.listProblemReports()).map((r) => r.id), [second.id, first.id]);

      final resolved = await api.resolveProblemReport(first.id);
      expect(resolved.status, ReportStatus.resolved);
      expect(resolved.resolvedAt, isNotNull);
      expect(resolved.resolvedBy?.employeeId, '31082');
      expect(resolved.nurse.employeeId, '48216'); // still the nurse who sent it

      expect((await api.listProblemReports()).map((r) => r.id), [second.id]);
      expect((await api.listProblemReports(status: ReportFilter.resolved)).map((r) => r.id), [first.id]);
      expect(await api.listProblemReports(status: ReportFilter.all), hasLength(2));
      await expectLater(api.resolveProblemReport(first.id), _apiError(409));
      await expectLater(api.resolveProblemReport(999), _apiError(404));
    });
  });
}
