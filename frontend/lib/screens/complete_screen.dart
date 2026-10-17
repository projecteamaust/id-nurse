import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../widgets/status_chip.dart';
import '../widgets/success_badge.dart';

/// Step 7: "Your transaction is recorded" (prototype: "complete" + Receipt in App.tsx).
///
/// A frontend-only step after Collect (Decision 6). Shows a short receipt from
/// GET /orders/{id}: order number, date and time, patient, nurse and the items.
/// For PARTIAL every line shows "dispensed of requested" with a chip, and the nurse is
/// told to report the problem to the supervisor. "New request" starts again at Patient.
/// The prototype's "Back to home" is left out (no Home screen yet); "Sign out" is in the top bar.
class CompleteScreen extends StatelessWidget {
  final int orderId;

  const CompleteScreen({super.key, required this.orderId});

  /// Tighter spacing (like the Prepare result), so 5 lines fit at 1280x720.
  static const _spacingReferenceHeight = 1000.0;

  @override
  Widget build(BuildContext context) {
    return NursePage(
      step: 6,
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
    final newRequest = AppButton(
      label: 'New request',
      onPressed: () => context.go('/patient'),
      height: scale.buttonHeight,
      textStyle: scale.button,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .complete-head: badge next to the heading.
        Row(
          children: [
            SuccessBadge(scale: scale),
            SizedBox(width: scale.size(AppSpacing.completeHeadGap)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (partial)
                    StatusChip(label: 'Partly dispensed', tone: ChipTone.warning, scale: scale)
                  else
                    Text('REQUEST COMPLETE', style: scale.text(AppText.eyebrow.copyWith(color: AppColors.success))),
                  SizedBox(height: scale.size(AppSpacing.gapXs)),
                  Text(partial ? 'Request recorded with missing items' : 'Your transaction is recorded', style: scale.h1),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        Flexible(child: _receipt(order, scale)),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        if (partial)
          Row(
            children: [
              Expanded(
                child: AppAlert(
                  key: const Key('supervisor-alert'),
                  message: 'Not dispensed: ${notDispensedText(order.items)}. Please report the problem to your supervisor.',
                  scale: scale,
                  margin: EdgeInsets.zero,
                ),
              ),
              SizedBox(width: scale.size(AppSpacing.gapXxl)),
              newRequest,
            ],
          )
        else
          Align(alignment: Alignment.centerRight, child: newRequest),
      ],
    );
  }

  /// .receipt: a header grid with the order facts, then the item lines.
  Widget _receipt(Order order, AppScale scale) {
    final partial = order.status == OrderStatus.partial;
    final when = DateTime.parse(order.completedAt ?? order.createdAt).toLocal();
    final facts = [
      ('Order number', '#${order.id}'),
      ('Date and time', DateFormat.yMMMd().add_jm().format(when)),
      ('Patient', '${order.patient.name} · ${order.patient.fileNumber}'),
      ('Nurse', order.nurse.name),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The prototype uses 2 columns; 4 in one row leaves room for the item lines.
            Container(
              color: AppColors.tableHeader,
              child: Row(
                children: [
                  for (final (label, value) in facts) Expanded(child: _fact(label, value, scale)),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Padding(
              padding: EdgeInsets.fromLTRB(
                scale.size(AppSpacing.receiptCellPaddingX),
                scale.size(AppSpacing.gapL),
                scale.size(AppSpacing.receiptCellPaddingX),
                scale.size(AppSpacing.gapXs),
              ),
              child: Text(partial ? 'Items' : 'Items dispensed', style: scale.text(AppText.h3)),
            ),
            Flexible(
              child: ListView.separated(
                key: const Key('receipt-list'),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: order.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.border),
                itemBuilder: (context, i) {
                  final line = order.items[i];
                  return OrderLineRow(
                    name: line.name,
                    slotNumber: line.slotNumber,
                    quantity: partial ? '${line.qtyDispensed} of ${line.qtyRequested}' : unitsLabel(line.qtyDispensed),
                    status: partial ? dispenseResultChip(line, scale) : null,
                    scale: scale,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One cell of .receipt-grid: small muted label, strong value.
  Widget _fact(String label, String value, AppScale scale) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: scale.size(AppSpacing.receiptCellPaddingX),
        vertical: scale.size(AppSpacing.receiptCellPaddingY),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: scale.small),
          SizedBox(height: scale.size(AppSpacing.gapXxs)),
          Text(value, style: scale.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
