import 'package:dio/dio.dart';
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

/// Talks to the FastAPI backend over HTTP (docs/api.md).
///
/// - The JWT from login is kept in memory only and sent as `Authorization: Bearer <token>`.
/// - Every error becomes an [ApiException] with the HTTP status and the server's `detail`,
///   exactly like MockApiService throws them, so the screens work with both services.
/// - When the server cannot be reached, the status code is 0.
/// - It does not implement DemoControls: the real backend has no "simulate fault" endpoint,
///   so those demo buttons are hidden.
class RealApiService implements ApiService {
  final Dio _dio;
  String? _token;

  RealApiService({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 15),
            )) {
    _dio.options.baseUrl = baseUrl;
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final token = _token;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  /// Message shown when the backend is not running or not reachable.
  static const unreachableMessage = 'Cannot reach the server';

  // ---------------------------------------------------------------- auth

  @override
  Future<LoginResponse> login(String employeeId, LoginMethod method, {String? password}) async {
    final json = await _send(() => _dio.post('/auth/login', data: {
          'employee_id': employeeId,
          'method': method.value,
          'password': ?password, // left out when null (nurses)
        }));
    final response = LoginResponse.fromJson(json as Map<String, dynamic>);
    _token = response.accessToken;
    return response;
  }

  @override
  Future<User> me() async => User.fromJson(await _send(() => _dio.get('/me')) as Map<String, dynamic>);

  @override
  void signOut() => _token = null;

  // ---------------------------------------------------------------- patients and items

  @override
  Future<Patient> getPatient(String fileNumber) async =>
      Patient.fromJson(await _send(() => _dio.get('/patients/${Uri.encodeComponent(fileNumber)}')) as Map<String, dynamic>);

  @override
  Future<List<Item>> getItems({String? category, String? search}) async {
    final json = await _send(() => _dio.get('/items', queryParameters: _query({'category': category, 'search': search})));
    return _list(json, Item.fromJson);
  }

  @override
  Future<Item> updateItemQuantity(int itemId, int quantity) async =>
      Item.fromJson(await _send(() => _dio.patch('/items/$itemId', data: {'quantity': quantity})) as Map<String, dynamic>);

  @override
  Future<List<LowStockItem>> getLowStock() async => _list(await _send(() => _dio.get('/reports/low-stock')), LowStockItem.fromJson);

  // ---------------------------------------------------------------- orders

  @override
  Future<Order> createOrder(String patientFileNumber, List<OrderLineRequest> items) async {
    final json = await _send(() => _dio.post('/orders', data: {
          'patient_file_number': patientFileNumber,
          'items': [for (final line in items) line.toJson()],
        }));
    return Order.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Order> approveOrder(int orderId) async =>
      Order.fromJson(await _send(() => _dio.post('/orders/$orderId/approve')) as Map<String, dynamic>);

  @override
  Future<Order> cancelOrder(int orderId) async =>
      Order.fromJson(await _send(() => _dio.post('/orders/$orderId/cancel')) as Map<String, dynamic>);

  @override
  Future<Order> getOrder(int orderId) async =>
      Order.fromJson(await _send(() => _dio.get('/orders/$orderId')) as Map<String, dynamic>);

  @override
  Future<List<OrderSummary>> listOrders({int limit = 20, int? nurseId, DateTime? from, DateTime? to}) async {
    final json = await _send(() => _dio.get('/orders',
        queryParameters: _query({'limit': limit, 'nurse_id': nurseId, 'from': _day(from), 'to': _day(to)})));
    return _list(json, OrderSummary.fromJson);
  }

  // ---------------------------------------------------------------- users, audit log and reports

  @override
  Future<List<User>> listUsers({String? role}) async =>
      _list(await _send(() => _dio.get('/users', queryParameters: _query({'role': role}))), User.fromJson);

  @override
  Future<List<AuditEntry>> listAudit({DateTime? from, DateTime? to, int? nurseId, int limit = 100}) async {
    final json = await _send(() => _dio.get('/audit',
        queryParameters: _query({'limit': limit, 'nurse_id': nurseId, 'from': _day(from), 'to': _day(to)})));
    return _list(json, AuditEntry.fromJson);
  }

  @override
  Future<String> exportDispenseCsv({DateTime? from, DateTime? to, int? nurseId}) async {
    final text = await _send(() => _dio.get('/reports/dispense.csv',
        queryParameters: _query({'nurse_id': nurseId, 'from': _day(from), 'to': _day(to)}),
        options: Options(responseType: ResponseType.plain)));
    return text as String;
  }

  // ---------------------------------------------------------------- problem reports

  @override
  Future<ProblemReport> reportProblem(int orderId, {String? note}) async =>
      ProblemReport.fromJson(await _send(() => _dio.post('/orders/$orderId/report', data: {'note': note})) as Map<String, dynamic>);

  @override
  Future<List<ProblemReport>> listProblemReports({ReportFilter status = ReportFilter.open}) async => _list(
      await _send(() => _dio.get('/problem-reports', queryParameters: {'status': status.value})), ProblemReport.fromJson);

  @override
  Future<ProblemReport> resolveProblemReport(int reportId) async =>
      ProblemReport.fromJson(await _send(() => _dio.post('/problem-reports/$reportId/resolve')) as Map<String, dynamic>);

  // ---------------------------------------------------------------- helpers

  /// Runs one request and returns the response body, or throws [ApiException].
  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  static ApiException _toApiException(DioException e) {
    final response = e.response;
    if (response == null) return const ApiException(0, unreachableMessage);
    final data = response.data;
    var detail = 'Request failed';
    if (data is Map && data['detail'] is String) {
      detail = data['detail'] as String;
    } else if (data is Map && data['detail'] is List && (data['detail'] as List).isNotEmpty) {
      detail = '${((data['detail'] as List).first as Map)['msg']}'; // FastAPI's default 422 list
    }
    return ApiException(response.statusCode ?? 0, detail);
  }

  static List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) =>
      (json as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();

  /// Query parameters without the empty ones.
  static Map<String, dynamic> _query(Map<String, dynamic> params) =>
      {for (final entry in params.entries) if (entry.value != null) entry.key: entry.value};

  /// `?from=` / `?to=` use only the date part: YYYY-MM-DD.
  static String? _day(DateTime? value) => value == null ? null : DateFormat('yyyy-MM-dd').format(value);
}
