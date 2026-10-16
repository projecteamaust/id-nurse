import 'order.dart';

/// One entry of GET /orders (docs/api.md). Used for "Recent requests" lists.
class OrderSummary {
  final int id;
  final OrderStatus status;
  final String patientFileNumber;
  final String nurseName;
  final String createdAt;
  final int itemCount;
  final int totalUnits;

  const OrderSummary({
    required this.id,
    required this.status,
    required this.patientFileNumber,
    required this.nurseName,
    required this.createdAt,
    required this.itemCount,
    required this.totalUnits,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: json['id'] as int,
        status: OrderStatus.fromJson(json['status'] as String),
        patientFileNumber: json['patient_file_number'] as String,
        nurseName: json['nurse_name'] as String,
        createdAt: json['created_at'] as String,
        itemCount: json['item_count'] as int,
        totalUnits: json['total_units'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.value,
        'patient_file_number': patientFileNumber,
        'nurse_name': nurseName,
        'created_at': createdAt,
        'item_count': itemCount,
        'total_units': totalUnits,
      };
}
