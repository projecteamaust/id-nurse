import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/finished_order_loader.dart';
import '../widgets/nurse_page.dart';
import '../widgets/order_line_row.dart';
import '../widgets/success_badge.dart';

/// Step 6: "Your items are ready" (prototype: CollectScreen in App.tsx).
///
/// A frontend-only step after DONE or PARTIAL (Decision 6): there is no new order state.
/// We have no door hardware, only a pickup box, so the prototype's "Open door" and the
/// "door still open" reminder are left out. The screen lists what is in the box
/// (lines with qty_dispensed > 0) and "I have collected my items" goes to Complete.
class CollectScreen extends StatelessWidget {
  final int orderId;

  const CollectScreen({super.key, required this.orderId});

  /// Tighter spacing (like the Prepare result), so 5 lines and the alert fit at 1280x720.
  static const _spacingReferenceHeight = 1000.0;

  @override
  Widget build(BuildContext context) {
    return NursePage(
      step: 5,
      spacingReferenceHeight: _spacingReferenceHeight,
      builder: (context, scale) => FinishedOrderLoader(
        orderId: orderId,
        scale: scale,
        builder: (order) => _build(context, order, scale),
      ),
    );
  }

  Widget _build(BuildContext context, Order order, AppScale scale) {
    final partial = order.status == OrderStatus.partial;
    final inBox = order.items.where((l) => l.qtyDispensed > 0).toList();

    // Left side (.collect-screen): badge, heading, pickup box, button. Centered.
    final ready = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SuccessBadge(scale: scale),
        SizedBox(height: scale.size(AppSpacing.gapL)),
        Text('READY FOR COLLECTION', style: scale.text(AppText.eyebrow.copyWith(color: AppColors.success))),
        SizedBox(height: scale.size(AppSpacing.gapXs)),
        Text('Your items are ready', style: scale.h1, textAlign: TextAlign.center),
        SizedBox(height: scale.size(AppSpacing.gapS)),
        Text('Take your items from the pickup box.', style: scale.bodyMuted, textAlign: TextAlign.center),
        SizedBox(height: scale.size(AppSpacing.gapXl)),
        _pickupBox(scale),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        AppButton(
          label: 'I have collected my items',
          onPressed: () => context.go('/complete/${order.id}'),
          height: scale.control(AppSpacing.largeButtonHeight),
          textStyle: scale.text(AppText.button.copyWith(fontSize: 20)),
          padding: EdgeInsets.symmetric(horizontal: scale.size(AppSpacing.buttonPaddingX)),
        ),
      ],
    );

    // Right side: what is in the box, and for PARTIAL what to do about the rest.
    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('In the pickup box', style: scale.text(AppText.h3)),
        SizedBox(height: scale.size(AppSpacing.gapM)),
        Flexible(
          child: OrderLineList(
            key: const Key('collect-list'),
            rows: [
              for (final line in inBox)
                OrderLineRow(
                  name: line.name,
                  slotNumber: line.slotNumber,
                  quantity: unitsLabel(line.qtyDispensed),
                  scale: scale,
                ),
            ],
          ),
        ),
        if (partial)
          AppAlert(
            key: const Key('supervisor-alert'),
            message: 'Some items could not be dispensed. Please report the problem to your supervisor.',
            scale: scale,
            margin: EdgeInsets.only(top: scale.size(AppSpacing.gapL)),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = scale.size(AppSpacing.twoColGap);
        if (constraints.maxWidth < AppSpacing.twoColBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [ready, SizedBox(height: gap), Flexible(child: contents)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ready),
            SizedBox(width: gap),
            Expanded(child: contents),
          ],
        );
      },
    );
  }

  /// The prototype's closed dispensing door (.door), relabelled as our pickup box.
  Widget _pickupBox(AppScale scale) {
    return Container(
      width: scale.size(AppSpacing.pickupBoxWidth),
      height: scale.size(AppSpacing.pickupBoxHeight),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.pickupBox,
        border: Border.all(color: AppColors.pickupBoxBorder, width: scale.size(AppSpacing.pickupBoxBorderWidth)),
        borderRadius: BorderRadius.circular(AppSpacing.pickupBoxRadius),
      ),
      child: Text('Pickup box', style: scale.text(AppText.h2)),
    );
  }
}
