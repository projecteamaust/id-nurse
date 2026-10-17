import 'package:flutter/material.dart';

import '../models/item.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'status_chip.dart';

/// One item on the Supplies screen (.supply-card): slot and stock chips, name,
/// units available, a − qty + stepper and "Add". Out-of-stock items are greyed out
/// and have no stepper.
class SupplyCard extends StatelessWidget {
  final Item item;

  /// Quantity chosen on the stepper (not yet in the request).
  final int qty;

  /// Highest quantity the stepper may reach (order limit and stock left).
  final int maxQty;

  final ValueChanged<int> onQtyChanged;
  final VoidCallback onAdd;
  final AppScale scale;

  const SupplyCard({
    super.key,
    required this.item,
    required this.qty,
    required this.maxQty,
    required this.onQtyChanged,
    required this.onAdd,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final out = item.outOfStock;
    final (String stockLabel, ChipTone stockTone) = out
        ? ('Out of stock', ChipTone.error)
        : item.lowStock
            ? ('Low · ${item.quantity}', ChipTone.warning)
            : ('In stock', ChipTone.success);
    final textColor = out ? AppColors.supplyDisabledText : null;

    return Container(
      constraints: BoxConstraints(minHeight: scale.size(AppSpacing.supplyCardMinHeight)),
      padding: EdgeInsets.all(scale.size(AppSpacing.supplyCardPadding)),
      decoration: BoxDecoration(
        color: out ? AppColors.supplyDisabledBg : AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusChip(label: 'Slot ${item.slotNumber}', scale: scale),
              const SizedBox(width: AppSpacing.gapS),
              StatusChip(label: stockLabel, tone: stockTone, scale: scale),
            ],
          ),
          SizedBox(height: scale.size(AppSpacing.gapXl)),
          Text(item.name, style: scale.text(AppText.h3).copyWith(color: textColor)),
          SizedBox(height: scale.size(AppSpacing.gapXxs)),
          Text(
            out ? 'Unavailable for this request' : '${item.quantity} units available',
            style: scale.text(AppText.small.copyWith(fontSize: 14)).copyWith(color: textColor),
          ),
          const Spacer(), // pushes the controls to the bottom (.supply-card p { flex: 1 })
          if (!out) ...[
            SizedBox(height: scale.size(AppSpacing.gapL)),
            _buildStepper(),
            SizedBox(height: scale.size(AppSpacing.keypadGap)),
            AppButton(
              label: 'Add',
              onPressed: qty > 0 ? onAdd : null,
              expand: true,
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
          ],
        ],
      ),
    );
  }

  /// − qty + (.stepper): 56 px buttons with the quantity between them.
  Widget _buildStepper() {
    Widget step(String label, String tooltip, VoidCallback? onPressed) => Semantics(
          label: tooltip,
          child: SizedBox(
            width: scale.size(AppSpacing.stepperButtonWidth),
            child: AppButton(
              label: label,
              variant: AppButtonVariant.secondary,
              height: scale.control(AppSpacing.stepperButtonHeight),
              textStyle: scale.text(AppText.keypadButton),
              padding: EdgeInsets.zero,
              expand: true,
              onPressed: onPressed,
            ),
          ),
        );

    return Row(
      children: [
        step('−', 'Fewer', qty > 0 ? () => onQtyChanged(qty - 1) : null),
        Expanded(
          child: Text('$qty', textAlign: TextAlign.center, style: scale.text(AppText.h3)),
        ),
        step('+', 'More', qty < maxQty ? () => onQtyChanged(qty + 1) : null),
      ],
    );
  }
}
