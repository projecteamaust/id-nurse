import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/audit_entry.dart';
import '../models/order.dart';
import '../models/order_summary.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_table.dart';
import '../widgets/app_alert.dart';
import '../widgets/log_filter_bar.dart';
import '../widgets/status_chip.dart';

enum _LogTab { orders, actions }

/// Supervisor dashboard page "Dispensing log" (prototype: Transactions):
/// - Orders: GET /orders (newest first) with date, order, patient, nurse, items, units, status.
/// - Actions: GET /audit, everything in the audit log: sign ins, approvals, picks, stock edits…
/// Both use the same filters ([LogFilterBar]): From / To day (inclusive) and Nurse.
/// The nurse filter keeps only what that nurse did, so the robot's own picks ("System")
/// are hidden while a nurse is chosen (docs/api.md).
class DispensingLogScreen extends StatefulWidget {
  const DispensingLogScreen({super.key});

  @override
  State<DispensingLogScreen> createState() => _DispensingLogScreenState();
}

class _DispensingLogScreenState extends State<DispensingLogScreen> {
  /// How many rows each table loads. Older rows are found with the date filters.
  static const _limit = 100;

  static const _orderColumns = [
    AdminColumn('Date and time', flex: 3),
    AdminColumn('Order', flex: 2),
    AdminColumn('Patient', flex: 2),
    AdminColumn('Nurse', flex: 3),
    AdminColumn('Items', flex: 1, alignEnd: true),
    AdminColumn('Units', flex: 1, alignEnd: true),
    AdminColumn('Status', flex: 2, alignEnd: true),
  ];

  static const _actionColumns = [
    AdminColumn('Time', flex: 3),
    AdminColumn('Who', flex: 3),
    AdminColumn('Action', flex: 3),
    AdminColumn('Order', flex: 2),
    AdminColumn('Summary', flex: 7),
  ];

  static final _timeFormat = DateFormat.MMMd().add_jm();

  _LogTab _tab = _LogTab.orders;
  LogFilters _filters = const LogFilters();

  List<OrderSummary>? _orders;
  List<AuditEntry>? _actions;
  bool _loading = false;
  String? _error;

  /// Counts loads, so an older (slower) answer never replaces a newer one.
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_loadId;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final results = await Future.wait([
        api.listOrders(limit: _limit, nurseId: _filters.nurseId, from: _filters.from, to: _filters.to),
        api.listAudit(limit: _limit, nurseId: _filters.nurseId, from: _filters.from, to: _filters.to),
      ]);
      if (!mounted || id != _loadId) return;
      setState(() {
        _orders = results[0] as List<OrderSummary>;
        _actions = results[1] as List<AuditEntry>;
      });
    } catch (_) {
      if (mounted && id == _loadId) setState(() => _error = 'Could not load the dispensing log. Try again.');
    } finally {
      if (mounted && id == _loadId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AppScale>();
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LogFilterBar(
            filters: _filters,
            onChanged: (filters) {
              setState(() => _filters = filters);
              _load();
            },
            scale: scale,
            leading: [
              _Segmented(
                labels: const ['Orders', 'Actions'],
                keys: const [Key('tab-orders'), Key('tab-actions')],
                selected: _tab.index,
                onSelect: (i) => setState(() => _tab = _LogTab.values[i]),
                scale: scale,
              ),
            ],
            trailing: [
              if (_loading)
                SizedBox.square(dimension: scale.size(20), child: const CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          SizedBox(height: scale.size(AppSpacing.gapXl)),
          if (_error != null)
            AppAlert(
              message: _error!,
              tone: AlertTone.error,
              scale: scale,
              margin: EdgeInsets.only(bottom: scale.size(AppSpacing.gapL)),
            ),
          Expanded(child: _tab == _LogTab.orders ? _buildOrders(scale) : _buildActions(scale)),
        ],
      ),
    );
  }

  Widget _buildOrders(AppScale scale) {
    final orders = _orders;
    if (orders == null) return const SizedBox.shrink();
    if (orders.isEmpty) return _empty('No orders match these filters.', scale);
    final small = _small(scale);
    return Align(
      alignment: Alignment.topCenter,
      child: AdminTable(
        bodyKey: const Key('log-orders-table'),
        columns: _orderColumns,
        scale: scale,
        rows: [
          for (final o in orders)
            [
              Text(_timeFormat.format(DateTime.parse(o.createdAt).toLocal()), style: small),
              Text('#${o.id}', style: scale.strong),
              Text(o.patientFileNumber, style: small),
              Text(o.nurseName, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${o.itemCount}', style: small),
              Text('${o.totalUnits}', style: small),
              orderStatusChip(o.status, scale),
            ],
        ],
      ),
    );
  }

  Widget _buildActions(AppScale scale) {
    final actions = _actions;
    if (actions == null) return const SizedBox.shrink();
    if (actions.isEmpty) return _empty('No actions match these filters.', scale);
    final small = _small(scale);
    return Align(
      alignment: Alignment.topCenter,
      child: AdminTable(
        bodyKey: const Key('log-actions-table'),
        columns: _actionColumns,
        scale: scale,
        rows: [
          for (final e in actions)
            [
              Text(_timeFormat.format(DateTime.parse(e.timestamp).toLocal()), style: small),
              Text(
                e.actor?.name ?? 'System',
                style: e.actor == null ? small.copyWith(color: AppColors.muted) : small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(e.actionLabel, style: scale.strong.copyWith(fontSize: small.fontSize), maxLines: 1),
              Text(e.orderId == null ? '–' : '#${e.orderId}', style: small),
              Text(e.summary, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
        ],
      ),
    );
  }

  TextStyle _small(AppScale scale) => scale.text(AppText.small.copyWith(fontSize: 14)).copyWith(color: AppColors.text);

  Widget _empty(String text, AppScale scale) => Center(child: Text(text, style: scale.bodyMuted));
}

/// Chip for an order status in the log: Done, Partly, Failed, Cancelled, Pending, Dispensing.
StatusChip orderStatusChip(OrderStatus status, AppScale scale) {
  final (String label, ChipTone tone) = switch (status) {
    OrderStatus.done => ('Done', ChipTone.success),
    OrderStatus.partial => ('Partly', ChipTone.warning),
    OrderStatus.failed => ('Failed', ChipTone.error),
    OrderStatus.cancelled => ('Cancelled', ChipTone.neutral),
    OrderStatus.pending => ('Pending', ChipTone.neutral),
    OrderStatus.dispensing => ('Dispensing', ChipTone.teal),
  };
  return StatusChip(label: label, tone: tone, scale: scale);
}

/// Two-way switch (.segmented): grey track, the chosen option white with teal text.
class _Segmented extends StatelessWidget {
  final List<String> labels;
  final List<Key> keys;
  final int selected;
  final ValueChanged<int> onSelect;
  final AppScale scale;

  const _Segmented({
    required this.labels,
    required this.keys,
    required this.selected,
    required this.onSelect,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.segmentedPadding),
      decoration: BoxDecoration(
        color: AppColors.segmentedBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              key: keys[i],
              onTap: () => onSelect(i),
              child: Container(
                height: scale.control(AppSpacing.segmentedButtonHeight) - 2 * AppSpacing.segmentedPadding,
                padding: EdgeInsets.symmetric(horizontal: scale.size(AppSpacing.segmentedButtonPaddingX)),
                alignment: Alignment.center,
                decoration: i == selected
                    ? BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: AppColors.segmentedShadow, blurRadius: 4, offset: Offset(0, 1))],
                      )
                    : null,
                child: Text(
                  labels[i],
                  style: scale.text(AppText.button.copyWith(fontSize: 15)).copyWith(
                        color: i == selected ? AppColors.primary : AppColors.text,
                        fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
