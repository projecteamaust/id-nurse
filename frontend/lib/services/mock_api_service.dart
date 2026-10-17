import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/audit_entry.dart';
import '../models/item.dart';
import '../models/login_response.dart';
import '../models/low_stock_item.dart';
import '../models/order.dart';
import '../models/order_summary.dart';
import '../models/patient.dart';
import '../models/problem_report.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'demo_controls.dart';

/// Fake backend for building the screens before the real API exists.
///
/// - Keeps its data as plain JSON maps (the same field names as docs/api.md) and turns
///   them into models with `fromJson`, exactly like the real service will.
/// - Follows the backend rules: same status codes, same error messages, same order states.
/// - An approved order really moves: PENDING -> DISPENSING -> DONE, one unit per
///   [pickInterval]. A failed pick (empty drawer) is retried once, then the order stops as
///   PARTIAL or FAILED (docs/order-flow-and-arm.md). Stock goes down only when a unit is
///   "picked", never at order creation.
/// - Writes every important action to an audit log, like the backend's `audit_log`, which
///   the dispensing log reads with GET /audit.
class MockApiService implements ApiService, DemoControls {
  /// Fake network delay on every call, so loading states can be seen.
  final Duration networkDelay;

  /// Time the fake robot needs to pick one unit.
  final Duration pickInterval;

  /// Where "now" comes from. Always the real time in the app; tests can pass a fake
  /// clock to create orders on other days (for the date filters).
  final DateTime Function() _clock;

  MockApiService({
    this.networkDelay = const Duration(milliseconds: 600),
    this.pickInterval = const Duration(seconds: 1),
    @visibleForTesting DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// TESTS ONLY: after this many units have been picked in an order, every further pick
  /// fails like an arm fault. 0 forces FAILED; fewer than the order's units forces PARTIAL.
  /// null (the default, and always in the app) = the arm never faults.
  @visibleForTesting
  int? failPicksAfterUnits;

  /// Same limit as the backend config MAX_QTY_PER_ITEM (default 30).
  static const maxQtyPerItem = 30;

  /// Demo-only supervisor password for the mock. Not a real secret: the real
  /// backend stores a PBKDF2 hash set from the seed.
  static const demoSupervisorPassword = 'demo';

  // ---------------------------------------------------------------- demo data
  // Matches the planned backend seed (docs/database.md): 2 users, 2 patients,
  // 6 items in slots 1-6 over 3 categories.

  final List<Map<String, dynamic>> _users = [
    {'id': 1, 'employee_id': '48216', 'name': 'Maya Chen', 'role': 'nurse', 'ward': 'Ward 4 · Surgical'},
    {'id': 2, 'employee_id': '31082', 'name': 'Elena Ruiz', 'role': 'supervisor', 'ward': 'Ward 4 · Surgical'},
  ];

  final List<Map<String, dynamic>> _patients = [
    {'id': 1, 'file_number': '284913', 'name': 'Alex Morgan', 'age': 34, 'room': '2B-12', 'diagnosis_code': 'T81.4'},
    {'id': 2, 'file_number': '548220', 'name': 'Sam Taylor', 'age': 61, 'room': '2A-04', 'diagnosis_code': 'L89.1'},
  ];

  final List<Map<String, dynamic>> _items = [
    {'id': 1, 'name': 'Sterile gauze pads', 'sku': 'WC-001', 'category': 'Wound care', 'slot_number': 1, 'quantity': 42, 'min_quantity': 10},
    {'id': 2, 'name': 'Adhesive dressing', 'sku': 'WC-002', 'category': 'Wound care', 'slot_number': 2, 'quantity': 9, 'min_quantity': 10},
    {'id': 3, 'name': 'IV administration set', 'sku': 'IV-001', 'category': 'IV and injections', 'slot_number': 3, 'quantity': 21, 'min_quantity': 5},
    {'id': 4, 'name': '10 ml syringe', 'sku': 'IV-002', 'category': 'IV and injections', 'slot_number': 4, 'quantity': 0, 'min_quantity': 10},
    {'id': 5, 'name': 'Nitrile gloves, M', 'sku': 'GP-001', 'category': 'Gloves and protection', 'slot_number': 5, 'quantity': 64, 'min_quantity': 20},
    {'id': 6, 'name': 'Procedure mask', 'sku': 'GP-002', 'category': 'Gloves and protection', 'slot_number': 6, 'quantity': 26, 'min_quantity': 10},
  ];

  final Map<int, Map<String, dynamic>> _orders = {};
  final Map<int, Timer> _robotTimers = {};
  int _nextOrderId = 1;

  /// audit_log rows: id, timestamp, actor (user id, or null for the system), action,
  /// order_id, summary and details (docs/api.md, GET /audit).
  final List<Map<String, dynamic>> _auditLog = [];
  int _nextAuditId = 1;
  Map<String, dynamic>? _currentUser;

  // ---------------------------------------------------------------- auth

  @override
  Future<LoginResponse> login(String employeeId, LoginMethod method, {String? password}) async {
    await _delay();
    final user = _users.where((u) => u['employee_id'] == employeeId).firstOrNull;
    if (user == null) {
      _writeAudit(null, 'login_failed', {'employee_id': employeeId}, summary: 'Sign in failed: no staff ID $employeeId');
      throw const ApiException(401, 'No staff ID found');
    }
    if (user['role'] == 'supervisor' && password != demoSupervisorPassword) {
      _writeAudit(user, 'login_failed', {}, summary: 'Sign in failed: wrong password');
      throw const ApiException(401, 'Wrong password');
    }
    // Nurse: a password, if sent, is ignored (docs/api.md).
    _currentUser = user;
    final how = method == LoginMethod.scan ? 'card scan' : 'employee ID';
    _writeAudit(user, 'login_success', {'method': method.value}, summary: '${user['name']} signed in ($how)');
    return LoginResponse.fromJson({
      'access_token': 'mock-token-${user['employee_id']}',
      'token_type': 'bearer',
      'expires_in': 28800,
      'user': user,
    });
  }

  @override
  Future<User> me() async {
    await _delay();
    return User.fromJson(_requireUser());
  }

  @override
  void signOut() => _currentUser = null;

  // ---------------------------------------------------------------- patients and items

  @override
  Future<Patient> getPatient(String fileNumber) async {
    await _delay();
    _requireUser();
    final patient = _patients.where((p) => p['file_number'] == fileNumber).firstOrNull;
    if (patient == null) throw const ApiException(404, 'No patient with this file number');
    return Patient.fromJson(patient);
  }

  @override
  Future<List<Item>> getItems({String? category, String? search}) async {
    await _delay();
    _requireUser();
    final query = search?.trim().toLowerCase() ?? '';
    return _items
        .where((i) => category == null || i['category'] == category)
        .where((i) => query.isEmpty || (i['name'] as String).toLowerCase().contains(query))
        .map((i) => Item.fromJson(_itemJson(i)))
        .toList();
  }

  /// Highest stock count PATCH /items/{id} accepts (docs/api.md).
  static const maxItemQuantity = 999;

  @override
  Future<Item> updateItemQuantity(int itemId, int quantity) async {
    await _delay();
    final user = _requireSupervisor();
    if (quantity < 0 || quantity > maxItemQuantity) {
      throw const ApiException(422, 'Quantity must be between 0 and $maxItemQuantity');
    }
    final item = _items.where((i) => i['id'] == itemId).firstOrNull;
    if (item == null) throw const ApiException(404, 'Item not found');
    final old = item['quantity'] as int;
    item['quantity'] = quantity;
    _writeAudit(user, 'stock_edit', {'item_id': itemId, 'old_quantity': old, 'new_quantity': quantity},
        summary: 'Set ${item['name']} to $quantity units (was $old)');
    return Item.fromJson(_itemJson(item));
  }

  @override
  Future<List<LowStockItem>> getLowStock() async {
    await _delay();
    _requireSupervisor();
    final low = _items.map(_itemJson).where((i) => i['low_stock'] as bool).toList()
      ..sort((a, b) {
        final byQty = (a['quantity'] as int).compareTo(b['quantity'] as int);
        return byQty != 0 ? byQty : (a['name'] as String).compareTo(b['name'] as String);
      });
    return [
      for (final i in low)
        LowStockItem.fromJson({...i, 'qty_to_minimum': (i['min_quantity'] as int) - (i['quantity'] as int)}),
    ];
  }

  // ---------------------------------------------------------------- orders

  @override
  Future<Order> createOrder(String patientFileNumber, List<OrderLineRequest> items) async {
    await _delay();
    final user = _requireUser();

    if (items.isEmpty) throw const ApiException(422, 'Order has no items');
    for (final line in items) {
      if (line.qty <= 0 || line.qty > maxQtyPerItem) {
        throw const ApiException(422, 'Quantity must be between 1 and $maxQtyPerItem');
      }
    }
    final patient = _patients.where((p) => p['file_number'] == patientFileNumber).firstOrNull;
    if (patient == null) throw const ApiException(404, 'No patient with this file number');

    final lines = <Map<String, dynamic>>[];
    for (final line in items) {
      final item = _items.where((i) => i['id'] == line.itemId).firstOrNull;
      if (item == null) throw ApiException(409, 'Item ${line.itemId} does not exist');
      if ((item['quantity'] as int) < line.qty) {
        throw ApiException(409, 'Not enough stock for ${item['name']}');
      }
      lines.add({
        'item_id': item['id'],
        'name': item['name'],
        'slot_number': item['slot_number'],
        'qty_requested': line.qty,
        'qty_dispensed': 0,
      });
    }

    final order = {
      'id': _nextOrderId++,
      'status': OrderStatus.pending.value,
      'patient': {'file_number': patient['file_number'], 'name': patient['name']},
      'nurse': {'employee_id': user['employee_id'], 'name': user['name']},
      'created_at': _now(),
      'approved_at': null,
      'completed_at': null,
      'items': lines,
    };
    _orders[order['id'] as int] = order;
    final units = lines.fold<int>(0, (sum, l) => sum + (l['qty_requested'] as int));
    final itemWord = lines.length == 1 ? 'item' : 'items';
    final unitWord = units == 1 ? 'unit' : 'units';
    _writeAudit(user, 'order_created', {}, orderId: order['id'] as int,
        summary: 'Created order #${order['id']} for patient ${patient['file_number']} '
            '(${lines.length} $itemWord, $units $unitWord)');
    return Order.fromJson(order);
  }

  @override
  Future<Order> approveOrder(int orderId) async {
    await _delay();
    final order = _requireOwnPendingOrder(orderId);
    order['status'] = OrderStatus.dispensing.value;
    order['approved_at'] = _now();
    _writeAudit(_currentUser, 'order_approved', {}, orderId: orderId, summary: 'Approved order #$orderId');
    _startRobot(orderId);
    return Order.fromJson(order);
  }

  @override
  Future<Order> cancelOrder(int orderId) async {
    await _delay();
    final order = _requireOwnPendingOrder(orderId);
    order['status'] = OrderStatus.cancelled.value;
    _writeAudit(_currentUser, 'order_cancelled', {}, orderId: orderId, summary: 'Cancelled order #$orderId');
    return Order.fromJson(order);
  }

  @override
  Future<Order> getOrder(int orderId) async {
    await _delay();
    return Order.fromJson(_requireVisibleOrder(orderId));
  }

  @override
  Future<List<OrderSummary>> listOrders({int limit = 20, int? nurseId, DateTime? from, DateTime? to}) async {
    await _delay();
    final user = _requireUser();
    final supervisor = user['role'] == 'supervisor';
    final inRange = _dayFilter(from, to);
    // nurse_id is the user id; orders store the nurse's employee_id.
    final nurseEmployeeId = nurseId == null ? null : _users.where((u) => u['id'] == nurseId).firstOrNull?['employee_id'];
    final visible = _orders.values
        .where((o) => supervisor || o['nurse']['employee_id'] == user['employee_id'])
        .where((o) => !supervisor || nurseId == null || o['nurse']['employee_id'] == nurseEmployeeId)
        .where((o) => inRange(o['created_at'] as String))
        .toList()
      ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int)); // newest first
    return visible.take(limit).map((o) {
      final lines = (o['items'] as List).cast<Map<String, dynamic>>();
      return OrderSummary.fromJson({
        'id': o['id'],
        'status': o['status'],
        'patient_file_number': o['patient']['file_number'],
        'nurse_name': o['nurse']['name'],
        'created_at': o['created_at'],
        'item_count': lines.length,
        'total_units': lines.fold<int>(0, (sum, l) => sum + (l['qty_requested'] as int)),
      });
    }).toList();
  }

  // ---------------------------------------------------------------- users and audit log

  @override
  Future<List<User>> listUsers({String? role}) async {
    await _delay();
    _requireSupervisor();
    return _users.where((u) => role == null || u['role'] == role).map(User.fromJson).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Most entries GET /audit returns (docs/api.md).
  static const maxAuditLimit = 500;

  @override
  Future<List<AuditEntry>> listAudit({DateTime? from, DateTime? to, int? nurseId, int limit = 100}) async {
    await _delay();
    _requireSupervisor();
    final inRange = _dayFilter(from, to);
    return _auditLog.reversed // newest first
        .where((e) => inRange(e['timestamp'] as String))
        .where((e) => nurseId == null || e['actor'] == nurseId)
        .take(limit.clamp(1, maxAuditLimit))
        .map((e) => AuditEntry.fromJson({
              'id': e['id'],
              'timestamp': e['timestamp'],
              'actor': e['actor'] == null ? null : _userRef(e['actor'] as int),
              'action': e['action'],
              'order_id': e['order_id'],
              'summary': e['summary'],
            }))
        .toList();
  }

  /// A test for "is this ISO timestamp's day between [from] and [to]?" (both inclusive,
  /// both optional). The day is the date part of the timestamp: the server's local date.
  /// [from] after [to] is a 422, like the backend.
  bool Function(String timestamp) _dayFilter(DateTime? from, DateTime? to) {
    final day = DateFormat('yyyy-MM-dd');
    final first = from == null ? null : day.format(from);
    final last = to == null ? null : day.format(to);
    if (first != null && last != null && first.compareTo(last) > 0) {
      throw const ApiException(422, 'from must not be after to');
    }
    return (timestamp) {
      final date = timestamp.substring(0, 10);
      return (first == null || date.compareTo(first) >= 0) && (last == null || date.compareTo(last) <= 0);
    };
  }

  // ---------------------------------------------------------------- problem reports
  // Stored like the backend stores them (docs/api.md): entries in an append-only audit log.
  // "problem_reported" is the report; "problem_resolved" marks it resolved. Status is worked out.

  /// Longest note the API accepts (docs/api.md).
  static const maxReportNoteLength = 200;

  @override
  Future<ProblemReport> reportProblem(int orderId, {String? note}) async {
    await _delay();
    final user = _requireUser();
    final order = _requireVisibleOrder(orderId);
    final text = (note == null || note.trim().isEmpty) ? null : note.trim();
    if (text != null && text.length > maxReportNoteLength) {
      throw const ApiException(422, 'Note must be at most $maxReportNoteLength characters');
    }
    if (order['status'] != OrderStatus.partial.value && order['status'] != OrderStatus.failed.value) {
      throw ApiException(409, 'Order is ${order['status']}, not PARTIAL or FAILED');
    }
    final alreadyOpen = _auditLog.any((e) =>
        e['action'] == 'problem_reported' && e['details']['order_id'] == orderId && _resolvedEntry(e['id']) == null);
    if (alreadyOpen) throw const ApiException(409, 'This order already has an open report');

    final lines = (order['items'] as List).cast<Map<String, dynamic>>();
    final entry = _writeAudit(user, 'problem_reported', orderId: orderId, summary: 'Reported a problem with order #$orderId', {
      'order_id': orderId,
      'note': text,
      'missing_items': [
        for (final l in lines)
          if ((l['qty_dispensed'] as int) < (l['qty_requested'] as int))
            {
              'item_id': l['item_id'],
              'name': l['name'],
              'slot_number': l['slot_number'],
              'qty_missing': (l['qty_requested'] as int) - (l['qty_dispensed'] as int),
            },
      ],
    });
    return _reportFrom(entry);
  }

  @override
  Future<List<ProblemReport>> listProblemReports({ReportFilter status = ReportFilter.open}) async {
    await _delay();
    _requireSupervisor();
    return _auditLog.reversed // newest first
        .where((e) => e['action'] == 'problem_reported')
        .map(_reportFrom)
        .where((r) => status == ReportFilter.all || r.status.value == status.value)
        .toList();
  }

  @override
  Future<ProblemReport> resolveProblemReport(int reportId) async {
    await _delay();
    final user = _requireSupervisor();
    final entry = _auditLog.where((e) => e['id'] == reportId && e['action'] == 'problem_reported').firstOrNull;
    if (entry == null) throw const ApiException(404, 'Report not found');
    if (_resolvedEntry(reportId) != null) throw const ApiException(409, 'Report is already resolved');
    final orderId = entry['details']['order_id'] as int;
    _writeAudit(user, 'problem_resolved', {'report_id': reportId},
        orderId: orderId, summary: 'Resolved the problem report for order #$orderId');
    return _reportFrom(entry);
  }

  /// The "problem_resolved" entry for this report, or null while it is open.
  Map<String, dynamic>? _resolvedEntry(int reportId) => _auditLog
      .where((e) => e['action'] == 'problem_resolved' && e['details']['report_id'] == reportId)
      .firstOrNull;

  /// Report JSON as the API returns it, built from its audit entries.
  ProblemReport _reportFrom(Map<String, dynamic> entry) {
    final resolved = _resolvedEntry(entry['id'] as int);
    final details = entry['details'] as Map<String, dynamic>;
    return ProblemReport.fromJson({
      'id': entry['id'],
      'order_id': details['order_id'],
      'status': resolved == null ? ReportStatus.open.value : ReportStatus.resolved.value,
      'note': details['note'],
      'nurse': _userRef(entry['actor'] as int),
      'missing_items': details['missing_items'],
      'created_at': entry['timestamp'],
      'resolved_at': resolved?['timestamp'],
      'resolved_by': resolved == null ? null : _userRef(resolved['actor'] as int),
    });
  }

  /// `{employee_id, name}` of a user id.
  Map<String, dynamic> _userRef(int userId) {
    final user = _users.firstWhere((u) => u['id'] == userId);
    return {'employee_id': user['employee_id'], 'name': user['name']};
  }

  /// Adds one audit_log row and returns it. [user] is null for the system (the robot).
  Map<String, dynamic> _writeAudit(
    Map<String, dynamic>? user,
    String action,
    Map<String, dynamic> details, {
    int? orderId,
    required String summary,
  }) {
    final entry = {
      'id': _nextAuditId++,
      'timestamp': _now(),
      'actor': user?['id'],
      'action': action,
      'order_id': orderId,
      'summary': summary,
      'details': details,
    };
    _auditLog.add(entry);
    return entry;
  }

  /// Stops the fake robot timers (used by tests).
  void dispose() {
    for (final timer in _robotTimers.values) {
      timer.cancel();
    }
    _robotTimers.clear();
  }

  // ---------------------------------------------------------------- fake robot

  /// Picks one unit per tick, like the backend (docs/order-flow-and-arm.md, step 6):
  /// a pick fails when the drawer is empty or the arm faults ([failPicksAfterUnits]).
  /// A failed pick is retried once on the next tick; if that fails too, the order stops.
  /// The order ends as DONE (everything picked), PARTIAL (some picked) or FAILED (nothing).
  void _startRobot(int orderId) {
    final order = _orders[orderId]!;
    final lines = (order['items'] as List).cast<Map<String, dynamic>>();
    var picked = 0; // units picked in this order
    var retrying = false; // the last pick failed; this tick is its one retry

    void finish(Timer timer) {
      final requested = lines.fold<int>(0, (s, l) => s + (l['qty_requested'] as int));
      final dispensed = lines.fold<int>(0, (s, l) => s + (l['qty_dispensed'] as int));
      order['status'] = dispensed == requested
          ? OrderStatus.done.value
          : dispensed > 0
              ? OrderStatus.partial.value
              : OrderStatus.failed.value;
      order['completed_at'] = _now();
      _writeAudit(null, 'order_finished', {}, orderId: orderId,
          summary: 'Order #$orderId finished: ${order['status']} ($dispensed of $requested units)');
      timer.cancel();
      _robotTimers.remove(orderId);
    }

    _robotTimers[orderId] = Timer.periodic(pickInterval, (timer) {
      final next = lines.where((l) => (l['qty_dispensed'] as int) < (l['qty_requested'] as int)).firstOrNull;
      if (next == null) return finish(timer);

      final item = _items.firstWhere((i) => i['id'] == next['item_id']);
      final armFault = (failPicksAfterUnits != null && picked >= failPicksAfterUnits!) ||
          _faultedOrders.contains(orderId);
      final where = '${next['name']} (slot ${next['slot_number']})';
      if (!armFault && (item['quantity'] as int) > 0) {
        item['quantity'] = (item['quantity'] as int) - 1; // stock goes down only on a real pick
        next['qty_dispensed'] = (next['qty_dispensed'] as int) + 1;
        picked++;
        retrying = false;
        _writeAudit(null, 'pick_ok', {'item_id': next['item_id']}, orderId: orderId, summary: 'Picked 1 × $where');
      } else {
        final reason = armFault ? 'arm fault' : 'drawer empty';
        _writeAudit(null, 'pick_failed', {'item_id': next['item_id'], 'reason': reason},
            orderId: orderId, summary: 'Pick failed: $where, $reason');
        if (!retrying) {
          retrying = true; // try this pick once more on the next tick
        } else {
          finish(timer); // retried and failed again: stop the order
        }
      }
    });
  }

  /// Orders whose arm "faulted" through [simulateArmFault] (demo mode).
  final Set<int> _faultedOrders = {};

  @override
  void simulateArmFault(int orderId) => _faultedOrders.add(orderId);

  // ---------------------------------------------------------------- helpers

  Future<void> _delay() => Future.delayed(networkDelay);

  Map<String, dynamic> _requireUser() {
    final user = _currentUser;
    if (user == null) throw const ApiException(401, 'Not signed in');
    return user;
  }

  Map<String, dynamic> _requireSupervisor() {
    final user = _requireUser();
    if (user['role'] != 'supervisor') throw const ApiException(403, 'Supervisors only');
    return user;
  }

  Map<String, dynamic> _requireVisibleOrder(int orderId) {
    final user = _requireUser();
    final order = _orders[orderId];
    if (order == null) throw const ApiException(404, 'Order not found');
    if (user['role'] != 'supervisor' && order['nurse']['employee_id'] != user['employee_id']) {
      throw const ApiException(403, 'Not your order');
    }
    return order;
  }

  Map<String, dynamic> _requireOwnPendingOrder(int orderId) {
    final order = _requireVisibleOrder(orderId);
    if (order['status'] != OrderStatus.pending.value) {
      throw ApiException(409, 'Order is ${order['status']}, not PENDING');
    }
    return order;
  }

  /// Item JSON as the API returns it, with the computed `low_stock` field.
  Map<String, dynamic> _itemJson(Map<String, dynamic> item) => {
        ...item,
        'low_stock': (item['quantity'] as int) <= (item['min_quantity'] as int),
      };

  /// Current time as ISO 8601 with the timezone offset, e.g. 2026-10-16T08:45:12+03:00.
  String _now() {
    final now = _clock();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now)}$sign$hours:$minutes';
  }
}
