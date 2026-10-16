import 'dart:async';

import 'package:intl/intl.dart';

import '../models/item.dart';
import '../models/login_response.dart';
import '../models/order.dart';
import '../models/order_summary.dart';
import '../models/patient.dart';
import '../models/user.dart';
import 'api_service.dart';

/// Fake backend for building the screens before the real API exists.
///
/// - Keeps its data as plain JSON maps (the same field names as docs/api.md) and turns
///   them into models with `fromJson`, exactly like the real service will.
/// - Follows the backend rules: same status codes, same error messages, same order states.
/// - An approved order really moves: PENDING -> DISPENSING -> DONE (or PARTIAL / FAILED
///   if a drawer runs empty), one unit per [pickInterval]. Stock goes down only when a
///   unit is "picked", never at order creation.
class MockApiService implements ApiService {
  /// Fake network delay on every call, so loading states can be seen.
  final Duration networkDelay;

  /// Time the fake robot needs to pick one unit.
  final Duration pickInterval;

  MockApiService({
    this.networkDelay = const Duration(milliseconds: 600),
    this.pickInterval = const Duration(seconds: 1),
  });

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
  Map<String, dynamic>? _currentUser;

  // ---------------------------------------------------------------- auth

  @override
  Future<LoginResponse> login(String employeeId, LoginMethod method, {String? password}) async {
    await _delay();
    final user = _users.where((u) => u['employee_id'] == employeeId).firstOrNull;
    if (user == null) throw const ApiException(401, 'No staff ID found');
    if (user['role'] == 'supervisor' && password != demoSupervisorPassword) {
      throw const ApiException(401, 'Wrong password');
    }
    // Nurse: a password, if sent, is ignored (docs/api.md).
    _currentUser = user;
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
    return Order.fromJson(order);
  }

  @override
  Future<Order> approveOrder(int orderId) async {
    await _delay();
    final order = _requireOwnPendingOrder(orderId);
    order['status'] = OrderStatus.dispensing.value;
    order['approved_at'] = _now();
    _startRobot(orderId);
    return Order.fromJson(order);
  }

  @override
  Future<Order> cancelOrder(int orderId) async {
    await _delay();
    final order = _requireOwnPendingOrder(orderId);
    order['status'] = OrderStatus.cancelled.value;
    return Order.fromJson(order);
  }

  @override
  Future<Order> getOrder(int orderId) async {
    await _delay();
    return Order.fromJson(_requireVisibleOrder(orderId));
  }

  @override
  Future<List<OrderSummary>> listOrders({int limit = 20}) async {
    await _delay();
    final user = _requireUser();
    final visible = _orders.values
        .where((o) => user['role'] == 'supervisor' || o['nurse']['employee_id'] == user['employee_id'])
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

  /// Stops the fake robot timers (used by tests).
  void dispose() {
    for (final timer in _robotTimers.values) {
      timer.cancel();
    }
    _robotTimers.clear();
  }

  // ---------------------------------------------------------------- fake robot

  /// Picks one unit per tick. If a drawer is empty the line is given up
  /// (the real backend retries once first). When nothing is left to pick the order
  /// ends as DONE (everything picked), PARTIAL (some picked) or FAILED (nothing picked).
  void _startRobot(int orderId) {
    final order = _orders[orderId]!;
    final lines = (order['items'] as List).cast<Map<String, dynamic>>();
    final givenUp = <int>{};

    _robotTimers[orderId] = Timer.periodic(pickInterval, (timer) {
      final next = lines.where((l) => l['qty_dispensed'] < l['qty_requested'] && !givenUp.contains(l['item_id'])).firstOrNull;

      if (next != null) {
        final item = _items.firstWhere((i) => i['id'] == next['item_id']);
        if ((item['quantity'] as int) > 0) {
          item['quantity'] = (item['quantity'] as int) - 1;
          next['qty_dispensed'] = (next['qty_dispensed'] as int) + 1;
        } else {
          givenUp.add(next['item_id'] as int);
        }
        return;
      }

      final requested = lines.fold<int>(0, (s, l) => s + (l['qty_requested'] as int));
      final dispensed = lines.fold<int>(0, (s, l) => s + (l['qty_dispensed'] as int));
      order['status'] = dispensed == requested
          ? OrderStatus.done.value
          : dispensed > 0
              ? OrderStatus.partial.value
              : OrderStatus.failed.value;
      order['completed_at'] = _now();
      timer.cancel();
      _robotTimers.remove(orderId);
    });
  }

  // ---------------------------------------------------------------- helpers

  Future<void> _delay() => Future.delayed(networkDelay);

  Map<String, dynamic> _requireUser() {
    final user = _currentUser;
    if (user == null) throw const ApiException(401, 'Not signed in');
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
  static String _now() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now)}$sign$hours:$minutes';
  }
}
