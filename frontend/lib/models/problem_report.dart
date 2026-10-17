/// Report status from docs/api.md. Worked out by the server from audit_log, never stored.
enum ReportStatus {
  open('open'),
  resolved('resolved');

  /// The exact text the API uses.
  final String value;
  const ReportStatus(this.value);

  static ReportStatus fromJson(String value) =>
      ReportStatus.values.firstWhere((s) => s.value == value,
          orElse: () => throw FormatException('Unknown report status: $value'));
}

/// `?status=` for GET /problem-reports.
enum ReportFilter {
  open('open'),
  resolved('resolved'),
  all('all');

  final String value;
  const ReportFilter(this.value);
}

/// `nurse` and `resolved_by` inside the report object.
class ReportUser {
  final String employeeId;
  final String name;

  const ReportUser({required this.employeeId, required this.name});

  factory ReportUser.fromJson(Map<String, dynamic> json) => ReportUser(
        employeeId: json['employee_id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'employee_id': employeeId, 'name': name};
}

/// One line in `missing_items`: a line where qty_dispensed < qty_requested.
class MissingItem {
  final int itemId;
  final String name;
  final int slotNumber;
  final int qtyMissing;

  const MissingItem({
    required this.itemId,
    required this.name,
    required this.slotNumber,
    required this.qtyMissing,
  });

  factory MissingItem.fromJson(Map<String, dynamic> json) => MissingItem(
        itemId: json['item_id'] as int,
        name: json['name'] as String,
        slotNumber: json['slot_number'] as int,
        qtyMissing: json['qty_missing'] as int,
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'name': name,
        'slot_number': slotNumber,
        'qty_missing': qtyMissing,
      };
}

/// The report object returned by POST /orders/{id}/report, GET /problem-reports and
/// POST /problem-reports/{id}/resolve. Dates stay ISO 8601 strings, like [Order].
class ProblemReport {
  final int id;
  final int orderId;
  final ReportStatus status;
  final String? note;
  final ReportUser nurse;
  final List<MissingItem> missingItems;
  final String createdAt;
  final String? resolvedAt;
  final ReportUser? resolvedBy;

  const ProblemReport({
    required this.id,
    required this.orderId,
    required this.status,
    required this.note,
    required this.nurse,
    required this.missingItems,
    required this.createdAt,
    required this.resolvedAt,
    required this.resolvedBy,
  });

  factory ProblemReport.fromJson(Map<String, dynamic> json) => ProblemReport(
        id: json['id'] as int,
        orderId: json['order_id'] as int,
        status: ReportStatus.fromJson(json['status'] as String),
        note: json['note'] as String?,
        nurse: ReportUser.fromJson(json['nurse'] as Map<String, dynamic>),
        missingItems: (json['missing_items'] as List)
            .map((e) => MissingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] as String,
        resolvedAt: json['resolved_at'] as String?,
        resolvedBy: json['resolved_by'] == null
            ? null
            : ReportUser.fromJson(json['resolved_by'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'status': status.value,
        'note': note,
        'nurse': nurse.toJson(),
        'missing_items': missingItems.map((e) => e.toJson()).toList(),
        'created_at': createdAt,
        'resolved_at': resolvedAt,
        'resolved_by': resolvedBy?.toJson(),
      };
}
