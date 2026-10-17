import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../models/low_stock_item.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_table.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import 'stock_screen.dart';

/// Supervisor dashboard page "Low stock" (GET /reports/low-stock): items at or below
/// their minimum, lowest first, with how many units bring each back to its minimum.
/// "Edit quantity" uses the Stock page's dialog; a refilled item leaves the list.
/// Keeps the sidebar badge ([AdminCounts.lowStock]) in step. Loads once; "Refresh" loads again.
class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  static const _columns = [
    AdminColumn('Slot', flex: 1),
    AdminColumn('Item', flex: 4),
    AdminColumn('Category', flex: 3),
    AdminColumn('Quantity', flex: 2, alignEnd: true),
    AdminColumn('Minimum', flex: 2, alignEnd: true),
    AdminColumn('To minimum', flex: 2, alignEnd: true),
    AdminColumn('Status', flex: 2, alignEnd: true),
    AdminColumn('', flex: 3, alignEnd: true),
  ];

  List<LowStockItem>? _items;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<ApiService>().getLowStock();
      if (!mounted) return;
      setState(() => _items = items);
      context.read<AdminCounts>().lowStock = items.length;
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the low stock list. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Item item, AppScale scale) async {
    final updated = await showDialog<Item>(
      context: context,
      barrierColor: AppColors.modalBackdrop,
      builder: (_) => StockEditDialog(item: item, scale: scale),
    );
    if (updated == null || !mounted) return;
    // Load again: the server decides what is low and the order (lowest first).
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stock updated: ${updated.name}, ${updated.quantity} units.'),
        backgroundColor: AppColors.toast,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AppScale>();
    final items = _items;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .section-head
          Row(
            children: [
              Expanded(
                child: Text(
                  'Items at or below their minimum. Refill them, then update the count.',
                  style: scale.bodyMuted,
                ),
              ),
              AppButton(
                label: 'Refresh',
                variant: AppButtonVariant.secondary,
                onPressed: _loading ? null : _load,
                height: scale.buttonHeight,
                textStyle: scale.button,
              ),
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
          Expanded(child: _buildTable(items, scale)),
        ],
      ),
    );
  }

  Widget _buildTable(List<LowStockItem>? items, AppScale scale) {
    if (items == null) {
      return _loading ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
    }
    if (items.isEmpty) {
      return Center(child: Text('No items are low on stock.', style: scale.bodyMuted));
    }
    return Align(
      alignment: Alignment.topCenter,
      child: AdminTable(
        bodyKey: const Key('low-stock-table'),
        columns: _columns,
        rows: [for (final low in items) _row(low, scale)],
        scale: scale,
      ),
    );
  }

  List<Widget> _row(LowStockItem low, AppScale scale) {
    final item = low.item;
    final small = scale.text(AppText.small.copyWith(fontSize: 14)).copyWith(color: AppColors.text);
    return [
      Text('${item.slotNumber}', style: scale.strong),
      Text(item.name, key: ValueKey('low-${item.id}'), style: scale.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(item.category, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
      Text('${item.quantity}', style: scale.strong),
      Text('${item.minQuantity}', style: small),
      // "+10" units to reach the minimum; "At minimum" when it is exactly there.
      Text(
        low.qtyToMinimum > 0 ? '+${low.qtyToMinimum}' : 'At minimum',
        key: ValueKey('to-min-${item.id}'),
        style: scale.strong.copyWith(color: AppColors.warning),
      ),
      stockChip(item, scale),
      AppButton(
        key: ValueKey('edit-${item.id}'),
        label: 'Edit quantity',
        variant: AppButtonVariant.ghost,
        onPressed: () => _edit(item, scale),
        height: scale.control(AppSpacing.chipHeight + 12),
        textStyle: scale.text(AppText.button.copyWith(fontSize: 15)),
      ),
    ];
  }
}
