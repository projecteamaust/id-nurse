import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Picture of the cabinet (.cabinet-wrap / .cabinet / .drawer): a grid of numbered slots.
/// The slot being picked from is highlighted; slots that are finished show ✓.
/// Fills the space it is given and centers the grid in it.
class CabinetDiagram extends StatelessWidget {
  final int slotCount;
  final int? activeSlot;
  final Set<int> finishedSlots;
  final AppScale scale;

  /// Slots per row (the prototype has 4 drawers per row for 12; we have 6 slots).
  static const columns = 3;

  const CabinetDiagram({
    super.key,
    required this.slotCount,
    required this.activeSlot,
    required this.finishedSlots,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final gap = scale.size(AppSpacing.drawerGap);
    final rows = (slotCount / columns).ceil();
    return Container(
      padding: EdgeInsets.all(scale.size(AppSpacing.cabinetPadding)),
      decoration: BoxDecoration(
        color: AppColors.cabinet,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.7, // .cabinet { width: 70% }
          child: Container(
            padding: EdgeInsets.all(scale.size(AppSpacing.cabinetInnerPadding)),
            decoration: BoxDecoration(
              color: AppColors.cabinetBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < rows; r++) ...[
                  if (r > 0) SizedBox(height: gap),
                  Row(
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) SizedBox(width: gap),
                        Expanded(
                          child: r * columns + c < slotCount ? _drawer(r * columns + c + 1) : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawer(int slot) {
    final active = slot == activeSlot;
    final finished = finishedSlots.contains(slot);
    return Container(
      key: ValueKey('drawer-$slot'),
      height: scale.size(AppSpacing.drawerHeight),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryLight : AppColors.card,
        border: Border.all(color: active ? AppColors.primary : AppColors.drawerBorder, width: 2),
        borderRadius: BorderRadius.circular(AppSpacing.drawerRadius),
        boxShadow: active
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), spreadRadius: 3)]
            : null,
      ),
      child: Text(
        finished ? 'Slot $slot ✓' : 'Slot $slot',
        style: scale.text(AppText.chip).copyWith(
          color: active ? AppColors.primary : (finished ? AppColors.success : AppColors.muted),
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}
