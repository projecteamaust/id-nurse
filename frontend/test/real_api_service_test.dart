import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/models/problem_report.dart';
import 'package:id_nurse/services/api_service.dart';
import 'package:id_nurse/services/demo_controls.dart';
import 'package:id_nurse/services/real_api_service.dart';

/// One canned answer of the fake server.
class _Reply {
  final int status;
  final Object? body; // JSON value, or a String sent as plain text
  final String contentType;

  const _Reply(this.status, this.body, {this.contentType = 'application/json'});
}

/// Stands in for the network: records every request and answers from [replies]
/// ("METHOD /path" -> reply). An unknown route behaves like a server that is not running.
class _FakeServer implements HttpClientAdapter {
  final Map<String, _Reply> replies;
  final List<RequestOptions> requests = [];
  final List<Object?> bodies = [];

  _FakeServer(this.replies);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    bodies.add(options.data);
    final reply = replies['${options.method} ${options.path}'];
    if (reply == null) {
      throw DioException.connectionError(requestOptions: options, reason: 'connection refused');
    }
    final text = reply.body is String ? reply.body as String : jsonEncode(reply.body);
    return ResponseBody.fromString(text, reply.status, headers: {
      Headers.contentTypeHeader: [reply.contentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

const _user = {'id': 1, 'employee_id': '48216', 'name': 'Maya Chen', 'role': 'nurse', 'ward': 'Ward 4 · Surgical'};
const _login = {'access_token': 'jwt-123', 'token_type': 'bearer', 'expires_in': 28800, 'user': _user};
const _order = {
  'id': 17,
  'status': 'DISPENSING',
  'patient': {'file_number': '284913', 'name': 'Alex Morgan'},
  'nurse': {'employee_id': '48216', 'name': 'Maya Chen'},
  'created_at': '2026-10-16T08:45:12+03:00',
  'approved_at': '2026-10-16T08:45:20+03:00',
  'completed_at': null,
  'items': [
    {'item_id': 1, 'name': 'Sterile gauze pads', 'slot_number': 1, 'cabinet_location': 'A1', 'qty_requested': 3, 'qty_dispensed': 1},
  ],
};

void main() {
  late _FakeServer server;
  late RealApiService api;

  RealApiService build(Map<String, _Reply> replies) {
    server = _FakeServer(replies);
    final dio = Dio()..httpClientAdapter = server;
    return api = RealApiService(baseUrl: 'http://127.0.0.1:8000', dio: dio);
  }

  test('login keeps the token in memory and sends it as a Bearer token; sign out forgets it', () async {
    build({'POST /auth/login': const _Reply(200, _login), 'GET /me': const _Reply(200, _user)});

    final response = await api.login('48216', LoginMethod.scan);
    expect(response.user.name, 'Maya Chen');
    expect(server.bodies.first, {'employee_id': '48216', 'method': 'scan'}, reason: 'no password for a nurse');
    expect(server.requests.first.headers.containsKey('Authorization'), isFalse);

    await api.me();
    expect(server.requests.last.headers['Authorization'], 'Bearer jwt-123');
    expect(server.requests.last.uri.toString(), 'http://127.0.0.1:8000/me');

    api.signOut();
    await api.me();
    expect(server.requests.last.headers.containsKey('Authorization'), isFalse);
  });

  test('supervisor login sends the password', () async {
    build({'POST /auth/login': const _Reply(200, _login)});
    await api.login('31082', LoginMethod.manual, password: 'pw');
    expect(server.bodies.single, {'employee_id': '31082', 'method': 'manual', 'password': 'pw'});
  });

  test('server errors become ApiException with the status and detail', () async {
    build({
      'POST /auth/login': const _Reply(401, {'detail': 'No staff ID found'}),
      'GET /patients/000000': const _Reply(404, {'detail': 'No patient with this file number'}),
      'POST /orders': const _Reply(422, {
        'detail': [
          {'loc': ['body', 'items'], 'msg': 'Field required'}
        ]
      }),
    });
    await expectLater(api.login('11111', LoginMethod.manual),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401).having((e) => e.detail, 'detail', 'No staff ID found')));
    await expectLater(api.getPatient('000000'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
    await expectLater(api.createOrder('284913', const []),
        throwsA(isA<ApiException>().having((e) => e.detail, 'detail', 'Field required')));
  });

  test('a server that is not running gives status 0', () async {
    build({});
    await expectLater(api.getItems(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 0).having((e) => e.detail, 'detail', RealApiService.unreachableMessage)));
  });

  test('orders: create, approve, get', () async {
    build({
      'POST /orders': _Reply(201, {..._order, 'status': 'PENDING', 'approved_at': null}),
      'POST /orders/17/approve': const _Reply(200, _order),
      'GET /orders/17': const _Reply(200, _order),
    });
    final created = await api.createOrder('284913', const [OrderLineRequest(itemId: 1, qty: 3)]);
    expect(created.status.value, 'PENDING');
    expect(server.bodies.single, {
      'patient_file_number': '284913',
      'items': [
        {'item_id': 1, 'qty': 3}
      ],
    });
    expect((await api.approveOrder(17)).status.value, 'DISPENSING');
    expect((await api.getOrder(17)).items.single.qtyDispensed, 1);
  });

  test('items keep the cabinet location; empty filters are not sent', () async {
    build({
      'GET /items': const _Reply(200, [
        {'id': 1, 'name': 'Sterile gauze pads', 'sku': 'WC-001', 'category': 'Wound care', 'slot_number': 1,
         'cabinet_location': 'A1', 'quantity': 42, 'min_quantity': 10, 'low_stock': false},
      ]),
    });
    final items = await api.getItems();
    expect(items.single.cabinetLocation, 'A1');
    expect(server.requests.single.queryParameters, isEmpty);
    await api.getItems(category: 'Wound care');
    expect(server.requests.last.queryParameters, {'category': 'Wound care'});
  });

  test('list filters send dates as YYYY-MM-DD and the nurse id', () async {
    build({'GET /orders': const _Reply(200, []), 'GET /audit': const _Reply(200, [])});
    await api.listOrders(limit: 100, nurseId: 1, from: DateTime(2026, 10, 1, 15, 30), to: DateTime(2026, 10, 16));
    expect(server.requests.last.queryParameters, {'limit': 100, 'nurse_id': 1, 'from': '2026-10-01', 'to': '2026-10-16'});
    await api.listAudit();
    expect(server.requests.last.queryParameters, {'limit': 100});
  });

  test('dispense CSV comes back as plain text', () async {
    const csv = 'order_id,created_at\n17,2026-10-16T08:45:12+03:00\n';
    build({'GET /reports/dispense.csv': const _Reply(200, csv, contentType: 'text/csv; charset=utf-8')});
    expect(await api.exportDispenseCsv(nurseId: 1), csv);
    expect(server.requests.single.queryParameters, {'nurse_id': 1});
  });

  test('problem reports', () async {
    const report = {
      'id': 52, 'order_id': 17, 'status': 'open', 'note': 'Drawer 2 looked jammed',
      'nurse': {'employee_id': '48216', 'name': 'Maya Chen'},
      'missing_items': [{'item_id': 2, 'name': 'Adhesive dressing', 'slot_number': 2, 'qty_missing': 1}],
      'created_at': '2026-10-16T08:47:03+03:00', 'resolved_at': null, 'resolved_by': null,
    };
    build({
      'POST /orders/17/report': const _Reply(201, report),
      'GET /problem-reports': const _Reply(200, [report]),
    });
    expect((await api.reportProblem(17, note: 'Drawer 2 looked jammed')).id, 52);
    expect(server.bodies.last, {'note': 'Drawer 2 looked jammed'});
    await api.listProblemReports(status: ReportFilter.all);
    expect(server.requests.last.queryParameters, {'status': 'all'});
  });

  test('has no demo controls (no fake-fault buttons with the real backend)', () {
    expect(build({}), isNot(isA<DemoControls>()));
  });
}
