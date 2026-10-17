import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/order_draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/nurse_page.dart';
import '../widgets/patient_card.dart';

/// "2 units", "1 unit".
String _units(int n) => '$n ${n == 1 ? 'unit' : 'units'}';

/// Step 4: "Review your request" (prototype: screen "review" in App.tsx).
/// Shows the patient and the chosen supplies from [OrderDraft]. "Authorize request"
/// creates the order (POST /orders -> PENDING) and approves it (POST /orders/{id}/approve
/// -> DISPENSING). The screen only talks to ApiService, never HTTP.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _connectionMessage = 'Could not reach the server. Try again.';

  /// Review stacks heading, patient card, up to 5 item lines, an error and the buttons,
  /// so (like Login) its spacing shrinks sooner: prototype size only at about 1130 px window
  /// height (1000 + 80 + 48) and 0.6x at 1280x720, which is what is needed there to fit
  /// 5 lines with an error message. Text size is not affected (see AppScale).
  static const _spacingReferenceHeight = 1000.0;

  bool _busy = false;
  String? _error;

  /// Set when the order was created but approving it failed. A retry then only
  /// approves this order, so the nurse never creates the same order twice.
  int? _pendingOrderId;

  Future<void> _authorize() async {
    if (_busy) return;
    final api = context.read<ApiService>();
    final draft = context.read<OrderDraft>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var orderId = _pendingOrderId;
      if (orderId == null) {
        final order = await api.createOrder(
          draft.patient!.fileNumber,
          [for (final line in draft.lines) OrderLineRequest(itemId: line.item.id, qty: line.qty)],
        );
        orderId = order.id;
        _pendingOrderId = orderId;
      }
      await api.approveOrder(orderId);
      if (!mounted) return;

      // Step 5 (order status) is not built yet: confirm and start a new request.
      messenger.showSnackBar(
        SnackBar(content: Text('Order #$orderId approved. The status screen comes in a later step.')),
      );
      context.go('/patient');
      draft.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 = not enough stock, 422 = invalid quantity: only fixable by changing the items.
      final fixable = _pendingOrderId == null && (e.statusCode == 409 || e.statusCode == 422);
      setState(() => _error = fixable ? '${e.detail}. Edit items and try again.' : _connectionMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _connectionMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Edit items": back to Supplies with the request kept. An order that was created but
  /// not approved is cancelled first (allowed only while PENDING, Decision 2).
  Future<void> _editItems() async {
    if (_busy) return;
    final orderId = _pendingOrderId;
    if (orderId != null) {
      setState(() => _busy = true);
      try {
        await context.read<ApiService>().cancelOrder(orderId);
      } catch (_) {
        // Go back anyway; the order stays PENDING and can never be dispensed without approval.
      }
      if (!mounted) return;
    }
    context.go('/supplies');
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OrderDraft>();
    final patient = draft.patient;
    if (patient == null || draft.isEmpty) {
      // Nothing to review (e.g. opened directly, or just approved): go to the right step.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(patient == null ? '/patient' : '/supplies');
      });
      return const SizedBox.shrink();
    }

    return NursePage(
      step: 3,
      spacingReferenceHeight: _spacingReferenceHeight,
      builder: (context, scale) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review your request', style: scale.h1),
          SizedBox(height: scale.size(AppSpacing.gapS)),
          Text('Confirm the patient and supplies before authorizing.', style: scale.bodyMuted),
          SizedBox(height: scale.size(AppSpacing.gapXxl)),
          PatientCard(patient: patient, scale: scale),
          SizedBox(height: scale.size(AppSpacing.gapXxl)),
          // Sized to its lines; if there are too many, it scrolls inside its own box.
          Flexible(child: _buildLines(draft, scale)),
          _buildTotal(draft.totalUnits, scale),
          if (_error != null)
            AppAlert(
              message: _error!,
              tone: AlertTone.error,
              scale: scale,
              margin: EdgeInsets.only(bottom: scale.size(AppSpacing.gapM)), // same as Login: tight at 1280x720
            ),
          _buildButtons(scale),
        ],
      ),
    );
  }

  /// The requested items (.review-list). Compact: one row per item with name, slot and
  /// units (the prototype puts the slot under the name), so 5 lines fit without scrolling.
  Widget _buildLines(OrderDraft draft, AppScale scale) {
    final lines = draft.lines;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard - 1),
        child: ListView.separated(
          key: const Key('review-list'),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: lines.length,
          separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.border),
          itemBuilder: (context, i) {
            final line = lines[i];
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: scale.size(AppSpacing.reviewLinePaddingX),
                vertical: scale.size(AppSpacing.reviewLinePaddingY),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(line.item.name, style: scale.strong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(width: scale.size(AppSpacing.gapL)),
                  Text('Slot ${line.item.slotNumber}', style: scale.text(AppText.small.copyWith(fontSize: 14))),
                  // Clear gap before the quantity, never smaller than 16 px on short windows.
                  SizedBox(width: math.max(AppSpacing.reviewSlotGapMin, scale.size(AppSpacing.reviewSlotGap))),
                  // Fixed-width, right-aligned quantity column so all rows line up. It grows
                  // with the text size (not the spacing), so "30 units" always fits.
                  SizedBox(
                    key: const Key('review-units'),
                    width: AppSpacing.reviewUnitsWidth * scale.textFactor,
                    child: Text(_units(line.qty), style: scale.strong, textAlign: TextAlign.right, maxLines: 1),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// "Total  n units", right-aligned (.summary-total).
  Widget _buildTotal(int total, AppScale scale) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        scale.size(AppSpacing.reviewLinePaddingX),
        scale.size(AppSpacing.gapS),
        scale.size(AppSpacing.reviewLinePaddingX),
        scale.size(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Total', style: scale.body),
          SizedBox(width: scale.size(AppSpacing.summaryTotalGap)),
          Text(_units(total), style: scale.strong),
        ],
      ),
    );
  }

  /// "Edit items" and "Authorize request", right-aligned (.button-row.end).
  Widget _buildButtons(AppScale scale) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: scale.size(AppSpacing.gapM),
      runSpacing: scale.size(AppSpacing.gapM),
      children: [
        AppButton(
          label: 'Edit items',
          variant: AppButtonVariant.secondary,
          onPressed: _busy ? null : _editItems,
          height: scale.buttonHeight,
          textStyle: scale.button,
        ),
        AppButton(
          label: _busy ? 'Authorizing…' : 'Authorize request',
          onPressed: _busy ? null : _authorize,
          height: scale.buttonHeight,
          textStyle: scale.button,
        ),
      ],
    );
  }
}
