import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'status_chip.dart';

/// "2 units", "1 unit".
String unitsLabel(int n) => '$n ${n == 1 ? 'unit' : 'units'}';

/// Result chip for one order line: Dispensed (all), Partly (some) or Not dispensed (none).
/// Used by the Prepare result and the Complete receipt so both use the same words.
StatusChip dispenseResultChip(OrderItem line, AppScale scale) {
  final (String label, ChipTone tone) = line.qtyDispensed >= line.qtyRequested
      ? ('Dispensed', ChipTone.success)
      : line.qtyDispensed > 0
          ? ('Partly', ChipTone.warning)
          : ('Not dispensed', ChipTone.error);
  return StatusChip(label: label, tone: tone, scale: scale);
}

/// Bordered list of [OrderLineRow]s with dividers (.review-list). Sized to its rows;
/// if there are more rows than fit, it scrolls inside its own box (never the page).
class OrderLineList extends StatelessWidget {
  final List<Widget> rows;

  const OrderLineList({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard - 1),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.border),
          itemBuilder: (context, i) => rows[i],
        ),
      ),
    );
  }
}

/// One compact order line: name, "Slot n", then a fixed-width right-aligned quantity
/// column, and optionally a fixed-width status column (a chip). Fixed columns make all
/// rows line up; the prototype puts the slot under the name, but one row lets 5 lines fit.
/// Used by Review (quantity "2 units") and the Prepare result (quantity "2 of 3" + chip).
class OrderLineRow extends StatelessWidget {
  final String name;
  final int slotNumber;
  final String quantity;
  final Widget? status;
  final AppScale scale;

  const OrderLineRow({
    super.key,
    required this.name,
    required this.slotNumber,
    required this.quantity,
    this.status,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    // Gap before each fixed column: scaled, but never below 16 px on short windows.
    final columnGap = math.max(AppSpacing.reviewSlotGapMin, scale.size(AppSpacing.reviewSlotGap));
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: scale.size(AppSpacing.reviewLinePaddingX),
        vertical: scale.size(AppSpacing.reviewLinePaddingY),
      ),
      child: Row(
        children: [
          Expanded(child: Text(name, style: scale.strong, maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(width: scale.size(AppSpacing.gapL)),
          Text('Slot $slotNumber', style: scale.text(AppText.small.copyWith(fontSize: 14))),
          SizedBox(width: columnGap),
          // Width follows the text size (not the spacing), so "30 units" always fits.
          SizedBox(
            key: const Key('line-quantity'),
            width: AppSpacing.reviewUnitsWidth * scale.textFactor,
            child: Text(quantity, style: scale.strong, textAlign: TextAlign.right, maxLines: 1),
          ),
          if (status != null) ...[
            SizedBox(width: columnGap),
            SizedBox(
              width: AppSpacing.lineStatusWidth * scale.textFactor,
              child: Align(alignment: Alignment.centerRight, child: status),
            ),
          ],
        ],
      ),
    );
  }
}
