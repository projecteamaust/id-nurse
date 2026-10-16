/// Order states from docs/api.md: PENDING -> DISPENSING -> DONE | PARTIAL | FAILED.
/// CANCELLED is possible only before approval.
enum OrderStatus {
  pending('PENDING'),
  dispensing('DISPENSING'),
  done('DONE'),
  partial('PARTIAL'),
  failed('FAILED'),
  cancelled('CANCELLED');

  /// The exact text the API uses.
  final String value;
  const OrderStatus(this.value);

  /// Final states: the status screen stops polling here.
  bool get isFinal => this == done || this == partial || this == failed || this == cancelled;

  static OrderStatus fromJson(String value) =>
      OrderStatus.values.firstWhere((s) => s.value == value,
          orElse: () => throw FormatException('Unknown order status: $value'));
}

/// `patient` inside the order object.
class OrderPatient {
  final String fileNumber;
  final String name;

  const OrderPatient({required this.fileNumber, required this.name});

  factory OrderPatient.fromJson(Map<String, dynamic> json) => OrderPatient(
        fileNumber: json['file_number'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'file_number': fileNumber, 'name': name};
}

/// `nurse` inside the order object.
class OrderNurse {
  final String employeeId;
  final String name;

  const OrderNurse({required this.employeeId, required this.name});

  factory OrderNurse.fromJson(Map<String, dynamic> json) => OrderNurse(
        employeeId: json['employee_id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'employee_id': employeeId, 'name': name};
}

/// One line in `items` inside the order object.
class OrderItem {
  final int itemId;
  final String name;
  final int slotNumber;
  final int qtyRequested;
  final int qtyDispensed;

  const OrderItem({
    required this.itemId,
    required this.name,
    required this.slotNumber,
    required this.qtyRequested,
    required this.qtyDispensed,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        itemId: json['item_id'] as int,
        name: json['name'] as String,
        slotNumber: json['slot_number'] as int,
        qtyRequested: json['qty_requested'] as int,
        qtyDispensed: json['qty_dispensed'] as int,
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'name': name,
        'slot_number': slotNumber,
        'qty_requested': qtyRequested,
        'qty_dispensed': qtyDispensed,
      };
}

/// The order object returned by POST /orders, approve, cancel and GET /orders/{id}.
/// Dates stay ISO 8601 strings exactly as the API sends them; screens format them with `intl`.
class Order {
  final int id;
  final OrderStatus status;
  final OrderPatient patient;
  final OrderNurse nurse;
  final String createdAt;
  final String? approvedAt;
  final String? completedAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.status,
    required this.patient,
    required this.nurse,
    required this.createdAt,
    required this.approvedAt,
    required this.completedAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        status: OrderStatus.fromJson(json['status'] as String),
        patient: OrderPatient.fromJson(json['patient'] as Map<String, dynamic>),
        nurse: OrderNurse.fromJson(json['nurse'] as Map<String, dynamic>),
        createdAt: json['created_at'] as String,
        approvedAt: json['approved_at'] as String?,
        completedAt: json['completed_at'] as String?,
        items: (json['items'] as List)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.value,
        'patient': patient.toJson(),
        'nurse': nurse.toJson(),
        'created_at': createdAt,
        'approved_at': approvedAt,
        'completed_at': completedAt,
        'items': items.map((e) => e.toJson()).toList(),
      };
}
