import '../models/item.dart';
import '../models/login_response.dart';
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

  /// POST /orders -> order with status PENDING
  Future<Order> createOrder(String patientFileNumber, List<OrderLineRequest> items);

  /// POST /orders/{id}/approve -> order with status DISPENSING
  Future<Order> approveOrder(int orderId);

  /// POST /orders/{id}/cancel -> order with status CANCELLED
  Future<Order> cancelOrder(int orderId);

  /// GET /orders/{id}
  Future<Order> getOrder(int orderId);

  /// GET /orders?limit= (newest first)
  Future<List<OrderSummary>> listOrders({int limit = 20});

  /// POST /orders/{id}/report -> report with status open (only PARTIAL or FAILED orders)
  Future<ProblemReport> reportProblem(int orderId, {String? note});

  /// GET /problem-reports?status= (supervisor, newest first)
  Future<List<ProblemReport>> listProblemReports({ReportFilter status = ReportFilter.open});

  /// POST /problem-reports/{id}/resolve -> report with status resolved (supervisor)
  Future<ProblemReport> resolveProblemReport(int reportId);
}
