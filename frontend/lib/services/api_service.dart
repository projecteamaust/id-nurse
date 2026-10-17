import '../models/audit_entry.dart';
import '../models/item.dart';
import '../models/login_response.dart';
import '../models/low_stock_item.dart';
import '../models/order.dart';
import '../models/order_summary.dart';
import '../models/patient.dart';
import '../models/problem_report.dart';
import '../models/user.dart';

/// Thrown when the API answers with an error.
/// Mirrors the backend: HTTP status code + FastAPI's `{"detail": "message"}`.
class ApiException implements Exception {
  final int statusCode;
  final String detail;

  const ApiException(this.statusCode, this.detail);

  @override
  String toString() => 'ApiException($statusCode): $detail';
}

/// How the nurse identified herself. Only written to the audit log by the server.
enum LoginMethod {
  scan('scan'),
  manual('manual');

  final String value;
  const LoginMethod(this.value);
}

/// One line of a new order: POST /orders `items`.
class OrderLineRequest {
  final int itemId;
  final int qty;

  const OrderLineRequest({required this.itemId, required this.qty});

  Map<String, dynamic> toJson() => {'item_id': itemId, 'qty': qty};
}

/// The contract between the screens and the backend (docs/api.md).
/// Screens only talk to this interface. Today MockApiService implements it;
/// later RealApiService will, and the screens will not change.
abstract class ApiService {
  /// POST /auth/login. Nurses send no password; supervisors must.
  Future<LoginResponse> login(String employeeId, LoginMethod method, {String? password});

  /// GET /me
  Future<User> me();

  /// Forget the token (the API has no logout endpoint; the JWT is only kept in memory).
  void signOut();

  /// GET /patients/{file_number}
  Future<Patient> getPatient(String fileNumber);

  /// GET /items with optional ?category= and ?search=
  Future<List<Item>> getItems({String? category, String? search});

  /// PATCH /items/{id} with {quantity} (supervisor) -> the updated item
  Future<Item> updateItemQuantity(int itemId, int quantity);

  /// GET /reports/low-stock (supervisor): items at or below their minimum, lowest first
  Future<List<LowStockItem>> getLowStock();

  /// POST /orders -> order with status PENDING
  Future<Order> createOrder(String patientFileNumber, List<OrderLineRequest> items);

  /// POST /orders/{id}/approve -> order with status DISPENSING
  Future<Order> approveOrder(int orderId);

  /// POST /orders/{id}/cancel -> order with status CANCELLED
  Future<Order> cancelOrder(int orderId);

  /// GET /orders/{id}
  Future<Order> getOrder(int orderId);

  /// GET /orders?limit= (newest first). A supervisor can filter by nurse (`?nurse_id=`, the
  /// user id) and by day (`?from=` / `?to=`, inclusive; only the date part is used).
  Future<List<OrderSummary>> listOrders({int limit = 20, int? nurseId, DateTime? from, DateTime? to});

  /// GET /users?role= (supervisor), sorted by name
  Future<List<User>> listUsers({String? role});

  /// GET /audit (supervisor): actions, newest first, filtered like [listOrders];
  /// [nurseId] keeps only actions done by that user
  Future<List<AuditEntry>> listAudit({DateTime? from, DateTime? to, int? nurseId, int limit = 100});

  /// POST /orders/{id}/report -> report with status open (only PARTIAL or FAILED orders)
  Future<ProblemReport> reportProblem(int orderId, {String? note});

  /// GET /problem-reports?status= (supervisor, newest first)
  Future<List<ProblemReport>> listProblemReports({ReportFilter status = ReportFilter.open});

  /// POST /problem-reports/{id}/resolve -> report with status resolved (supervisor)
  Future<ProblemReport> resolveProblemReport(int reportId);
}
