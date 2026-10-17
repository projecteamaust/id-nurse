import 'problem_report.dart';

/// Action names in `audit_log` (docs/api.md, GET /audit), with the short label the
/// dispensing log shows.
const auditActionLabels = {
  'login_success': 'Signed in',
  'login_failed': 'Sign in failed',
  'order_created': 'Order created',
  'order_approved': 'Order approved',
  'order_cancelled': 'Order cancelled',
  'pick_ok': 'Item picked',
  'pick_failed': 'Pick failed',
  'order_finished': 'Order finished',
  'stock_edit': 'Stock edited',
  'pose_saved': 'Arm pose saved',
  'problem_reported': 'Problem reported',
  'problem_resolved': 'Problem resolved',
};

/// One entry of GET /audit. `actor` has the same `{employee_id, name}` shape as a
/// report's `nurse`, so it reuses [ReportUser]; it is null for the robot's own actions.
class AuditEntry {
  final int id;
  final String timestamp;
  final ReportUser? actor;
  final String action;
  final int? orderId;
  final String summary;

  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.actor,
    required this.action,
    required this.orderId,
    required this.summary,
  });

  /// "Order approved"; an unknown action name is shown as it is.
  String get actionLabel => auditActionLabels[action] ?? action;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id'] as int,
        timestamp: json['timestamp'] as String,
        actor: json['actor'] == null ? null : ReportUser.fromJson(json['actor'] as Map<String, dynamic>),
        action: json['action'] as String,
        orderId: json['order_id'] as int?,
        summary: json['summary'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'actor': actor?.toJson(),
        'action': action,
        'order_id': orderId,
        'summary': summary,
      };
}
