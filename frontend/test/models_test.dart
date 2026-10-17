import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/models/item.dart';
import 'package:id_nurse/models/login_response.dart';
import 'package:id_nurse/models/low_stock_item.dart';
import 'package:id_nurse/models/order.dart';
import 'package:id_nurse/models/order_summary.dart';
import 'package:id_nurse/models/patient.dart';
import 'package:id_nurse/models/problem_report.dart';

// The JSON examples below are copied from docs/api.md.
// Each test parses one and checks that toJson gives back exactly the same JSON,
// so the models use the same field names as the API contract.

Map<String, dynamic> _parse(String source) => jsonDecode(source) as Map<String, dynamic>;

void main() {
  test('LoginResponse matches POST /auth/login', () {
    final json = _parse('''
      { "access_token": "<jwt>", "token_type": "bearer", "expires_in": 28800,
        "user": { "id": 1, "employee_id": "48216", "name": "Maya Chen", "role": "nurse", "ward": "Ward 4 · Surgical" } }
    ''');
    final login = LoginResponse.fromJson(json);
    expect(login.user.name, 'Maya Chen');
    expect(login.user.isSupervisor, isFalse);
    expect(login.toJson(), json);
  });

  test('LowStockItem matches GET /reports/low-stock', () {
    final json = _parse('''
      { "id": 4, "name": "10 ml syringe", "sku": "IV-002", "category": "IV and injections",
        "slot_number": 4, "quantity": 0, "min_quantity": 10, "low_stock": true, "qty_to_minimum": 10 }
    ''');
    final low = LowStockItem.fromJson(json);
    expect(low.item.outOfStock, isTrue);
    expect(low.qtyToMinimum, 10);
    expect(low.toJson(), json);
  });

  test('Patient matches GET /patients/{file_number}', () {
    final json = _parse('''
      { "id": 1, "file_number": "284913", "name": "Alex Morgan", "age": 34, "room": "2B-12", "diagnosis_code": "T81.4" }
    ''');
    expect(Patient.fromJson(json).toJson(), json);
  });

  test('Item matches GET /items', () {
    final json = _parse('''
      { "id": 1, "name": "Sterile gauze pads", "sku": "WC-001", "category": "Wound care",
        "slot_number": 3, "quantity": 42, "min_quantity": 10, "low_stock": false }
    ''');
    final item = Item.fromJson(json);
    expect(item.outOfStock, isFalse);
    expect(item.toJson(), json);
  });

  test('Order matches GET /orders/{id}', () {
    final json = _parse('''
      { "id": 17, "status": "DISPENSING",
        "patient": { "file_number": "284913", "name": "Alex Morgan" },
        "nurse":   { "employee_id": "48216", "name": "Maya Chen" },
        "created_at": "2026-10-16T08:45:12+03:00", "approved_at": "2026-10-16T08:45:20+03:00", "completed_at": null,
        "items": [ { "item_id": 1, "name": "Sterile gauze pads", "slot_number": 3, "qty_requested": 3, "qty_dispensed": 1 } ] }
    ''');
    final order = Order.fromJson(json);
    expect(order.status, OrderStatus.dispensing);
    expect(order.status.isFinal, isFalse);
    expect(order.toJson(), json);
  });

  test('OrderSummary matches GET /orders', () {
    final json = _parse('''
      { "id": 17, "status": "DONE", "patient_file_number": "284913", "nurse_name": "Maya Chen",
        "created_at": "2026-10-16T08:45:12+03:00", "item_count": 3, "total_units": 7 }
    ''');
    expect(OrderSummary.fromJson(json).toJson(), json);
  });

  test('OrderStatus uses the exact API texts and knows the final states', () {
    expect(OrderStatus.values.map((s) => s.value),
        ['PENDING', 'DISPENSING', 'DONE', 'PARTIAL', 'FAILED', 'CANCELLED']);
    expect(OrderStatus.fromJson('PARTIAL'), OrderStatus.partial);
    expect(OrderStatus.done.isFinal && OrderStatus.partial.isFinal && OrderStatus.failed.isFinal, isTrue);
    expect(() => OrderStatus.fromJson('READY'), throwsFormatException);
  });

  test('ProblemReport matches the report object (open, then resolved)', () {
    final open = _parse('''
      { "id": 52, "order_id": 17, "status": "open", "note": "Drawer 2 looked jammed",
        "nurse": { "employee_id": "48216", "name": "Maya Chen" },
        "missing_items": [ { "item_id": 2, "name": "Adhesive dressing", "slot_number": 2, "qty_missing": 1 } ],
        "created_at": "2026-10-16T08:47:03+03:00", "resolved_at": null, "resolved_by": null }
    ''');
    final report = ProblemReport.fromJson(open);
    expect(report.status, ReportStatus.open);
    expect(report.missingItems.single.qtyMissing, 1);
    expect(report.toJson(), open);

    final resolved = {
      ...open,
      'status': 'resolved',
      'note': null,
      'resolved_at': '2026-10-16T09:10:00+03:00',
      'resolved_by': {'employee_id': '31082', 'name': 'Elena Ruiz'},
    };
    expect(ProblemReport.fromJson(resolved).toJson(), resolved);
    expect(() => ReportStatus.fromJson('closed'), throwsFormatException);
  });
}
