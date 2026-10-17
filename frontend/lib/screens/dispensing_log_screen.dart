import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/audit_entry.dart';
import '../models/order.dart';
import '../models/order_summary.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_table.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/status_chip.dart';

enum _LogTab { orders, actions }

/// Supervisor dashboard page "Dispensing log" (prototype: Transactions):
/// - Orders: GET /orders (newest first) with date, order, patient, nurse, items, units, status.
/// - Actions: GET /audit, everything in the audit log: sign ins, approvals, picks, stock edits…
/// Both use the same filters: From / To day (inclusive) and Nurse (GET /users?role=nurse).
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

  static final _dayFormat = DateFormat.yMMMd();
  static final _timeFormat = DateFormat.MMMd().add_jm();

  _LogTab _tab = _LogTab.orders;
  DateTime? _from;
  DateTime? _to;
  int? _nurseId;

  List<User> _nurses = const [];
  List<OrderSummary>? _orders;
  List<AuditEntry>? _actions;
  bool _loading = false;
  String? _error;

  /// Counts loads, so an older (slower) answer never replaces a newer one.
  int _loadId = 0;

  bool get _hasFilters => _from != null || _to != null || _nurseId != null;

  @override
  void initState() {
    super.initState();
    _loadNurses();
    _load();
  }

  Future<void> _loadNurses() async {
    try {
      final nurses = await context.read<ApiService>().listUsers(role: 'nurse');
      if (mounted) setState(() => _nurses = nurses);
    } catch (_) {
      // Without the list the nurse filter just offers "All nurses".
    }
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
        api.listOrders(limit: _limit, nurseId: _nurseId, from: _from, to: _to),
        api.listAudit(limit: _limit, nurseId: _nurseId, from: _from, to: _to),
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

  /// Opens Flutter's date picker. From can not be after To, and To not before From.
  Future<void> _pickDay({required bool from}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = from ? _from : _to;
    final first = from ? DateTime(2020) : (_from ?? DateTime(2020));
    final last = from ? (_to ?? today) : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? (last.isBefore(today) ? last : today),
      firstDate: first,
      lastDate: last,
      helpText: from ? 'Show from' : 'Show until',
    );
    if (picked == null || !mounted) return;
    setState(() => from ? _from = picked : _to = picked);
    _load();
  }

  void _clearFilters() {
    setState(() {
      _from = null;
      _to = null;
      _nurseId = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AppScale>();
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(scale),
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

  /// .toolbar: Orders | Actions, then the filters. Wraps onto a second line on narrow windows.
  Widget _buildToolbar(AppScale scale) {
    final gap = scale.size(AppSpacing.toolbarGap);
    String day(DateTime? d) => d == null ? 'any day' : _dayFormat.format(d);
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Segmented(
          labels: const ['Orders', 'Actions'],
          keys: const [Key('tab-orders'), Key('tab-actions')],
          selected: _tab.index,
          onSelect: (i) => setState(() => _tab = _LogTab.values[i]),
          scale: scale,
        ),
        AppButton(
          key: const Key('filter-from'),
          label: 'From: ${day(_from)}',
          variant: AppButtonVariant.secondary,
          onPressed: () => _pickDay(from: true),
          height: scale.buttonHeight,
          textStyle: scale.text(AppText.button.copyWith(fontSize: 15)),
        ),
        AppButton(
          key: const Key('filter-to'),
          label: 'To: ${day(_to)}',
          variant: AppButtonVariant.secondary,
          onPressed: () => _pickDay(from: false),
          height: scale.buttonHeight,
          textStyle: scale.text(AppText.button.copyWith(fontSize: 15)),
        ),
        _buildNurseFilter(scale),
        AppButton(
          label: 'Clear filters',
          variant: AppButtonVariant.ghost,
          onPressed: _hasFilters ? _clearFilters : null,
          height: scale.buttonHeight,
          textStyle: scale.text(AppText.button.copyWith(fontSize: 15)),
        ),
        if (_loading) SizedBox.square(dimension: scale.size(20), child: const CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }

  /// "All nurses" or one nurse, in a field that looks like the secondary buttons.
  Widget _buildNurseFilter(AppScale scale) {
    final style = scale.text(AppText.button.copyWith(fontSize: 15, color: AppColors.text));
    return Container(
      width: AppSpacing.nurseFilterWidth * scale.textFactor,
      height: scale.buttonHeight,
      padding: EdgeInsets.symmetric(horizontal: scale.size(AppSpacing.gapL)),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          key: const Key('filter-nurse'),
          value: _nurseId,
          isExpanded: true,
          style: style,
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text('All nurses', style: style)),
            for (final n in _nurses) DropdownMenuItem<int?>(value: n.id, child: Text(n.name, style: style)),
          ],
          onChanged: (id) {
            setState(() => _nurseId = id);
            _load();
          },
        ),
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
