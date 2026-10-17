import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/admin_shell.dart';
import '../widgets/admin_table.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/status_chip.dart';

/// Supervisor dashboard page "Stock" (prototype: Inventory & drawers, Table view):
/// every item with slot, category, quantity, minimum and a status chip, and
/// "Edit quantity" (PATCH /items/{id}) for a refill or a stock check.
/// Loads once when it opens; "Refresh" loads again.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  static const _columns = [
    AdminColumn('Slot', flex: 1),
    AdminColumn('Item', flex: 4),
    AdminColumn('Category', flex: 3),
    AdminColumn('Quantity', flex: 2, alignEnd: true),
    AdminColumn('Minimum', flex: 2, alignEnd: true),
    AdminColumn('Status', flex: 2, alignEnd: true),
    AdminColumn('', flex: 3, alignEnd: true),
  ];

  List<Item>? _items;
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
      final items = await context.read<ApiService>().getItems();
      if (mounted) setState(() => _items = [...items]..sort((a, b) => a.slotNumber.compareTo(b.slotNumber)));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the stock. Try again.');
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
    setState(() => _items = [for (final i in _items!) i.id == updated.id ? updated : i]);
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
                  'Every item in the cabinet. Edit a quantity after a refill or a stock check.',
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
          Expanded(
            child: items == null
                ? (_loading ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink())
                : Align(
                    alignment: Alignment.topCenter,
                    child: AdminTable(
                      bodyKey: const Key('stock-table'),
                      columns: _columns,
                      rows: [for (final item in items) _row(item, scale)],
                      scale: scale,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _row(Item item, AppScale scale) {
    final small = scale.text(AppText.small.copyWith(fontSize: 14)).copyWith(color: AppColors.text);
    return [
      Text('${item.slotNumber}', style: scale.strong),
      Text(item.name, style: scale.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(item.category, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
      Text('${item.quantity}', key: ValueKey('qty-${item.id}'), style: scale.strong),
      Text('${item.minQuantity}', style: small),
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

/// Empty (0), Low (at or below the minimum) or In stock, like the prototype's drawer chips.
StatusChip stockChip(Item item, AppScale scale) {
  final (String label, ChipTone tone) = item.outOfStock
      ? ('Empty', ChipTone.error)
      : item.lowStock
          ? ('Low', ChipTone.warning)
          : ('In stock', ChipTone.success);
  return StatusChip(label: label, tone: tone, scale: scale);
}

/// "Edit stock" dialog: the new quantity (0 to 999). Closes with the updated [Item]
/// from PATCH /items/{id}, or null on Cancel. Save is off while the field is empty or unchanged.
class StockEditDialog extends StatefulWidget {
  final Item item;
  final AppScale scale;

  const StockEditDialog({super.key, required this.item, required this.scale});

  @override
  State<StockEditDialog> createState() => _StockEditDialogState();
}

class _StockEditDialogState extends State<StockEditDialog> {
  late final _quantity = TextEditingController(text: '${widget.item.quantity}');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quantity.selection = TextSelection(baseOffset: 0, extentOffset: _quantity.text.length);
    _quantity.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  int? get _newQuantity => int.tryParse(_quantity.text);

  bool get _canSave => !_saving && _newQuantity != null && _newQuantity != widget.item.quantity;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await context.read<ApiService>().updateItemQuantity(widget.item.id, _newQuantity!);
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.detail;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the quantity. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final item = widget.item;
    return AppDialog(
      title: 'Edit stock · ${item.name}',
      subtitle: 'Slot ${item.slotNumber} · now ${item.quantity} units · minimum ${item.minQuantity}',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New quantity', style: scale.label),
          SizedBox(height: scale.size(AppSpacing.gapXs)),
          TextField(
            key: const Key('stock-quantity'),
            controller: _quantity,
            enabled: !_saving,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            style: scale.body,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      error: _error,
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          height: scale.buttonHeight,
          textStyle: scale.button,
        ),
        AppButton(
          label: _saving ? 'Saving…' : 'Save',
          onPressed: _canSave ? _save : null,
          height: scale.buttonHeight,
          textStyle: scale.button,
        ),
      ],
      scale: scale,
    );
  }
}
