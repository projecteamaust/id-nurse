import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/order.dart';
import '../models/order_progress.dart';
import '../services/api_service.dart';
import '../services/demo_controls.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/cabinet_diagram.dart';
import '../widgets/nurse_page.dart';
import '../widgets/order_line_row.dart';
import '../widgets/report_problem_dialog.dart';
import '../widgets/status_chip.dart';
import '../widgets/working_steps.dart';

/// Step 5: "Preparing your request" (prototype: RobotScreen in App.tsx).
///
/// Polls GET /orders/{id} every [AppConfig.pollInterval] until the order is final and
/// shows progress per item, worked out from `qty_dispensed` ([OrderProgress]).
/// There is no cancel button: cancel is only allowed before approval (Decision 2).
/// Demo mode with the mock adds "Simulate robot fault", so PARTIAL and FAILED can be shown.
/// - DONE -> the Collect step.
/// - PARTIAL / FAILED -> the result view on this screen, listing what was and wasn't
///   dispensed (Decisions 3 and 6).
class PrepareScreen extends StatefulWidget {
  final int orderId;

  const PrepareScreen({super.key, required this.orderId});

  @override
  State<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends State<PrepareScreen> {
  /// Stages shown above the cabinet. The prototype also has "Packing in one container",
  /// but the API has no such state, so we only show steps that really happen.
  static const _stages = ['Request received', 'Retrieving items', 'Ready for collection'];

  /// Same tighter spacing as Review, so 5 result rows fit at 1280x720.
  static const _resultSpacingReferenceHeight = 1000.0;

  Order? _order;
  bool _pollFailed = false; // the last poll failed; we keep trying
  bool _polling = false; // a GET is in flight; skip ticks until it returns
  bool _faultSimulated = false; // demo: "Simulate robot fault" was tapped
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(AppConfig.pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final order = await context.read<ApiService>().getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _pollFailed = false;
      });
      if (order.status.isFinal) {
        _timer?.cancel(); // final: stop polling
        if (order.status == OrderStatus.done) context.go('/collect/${order.id}');
      }
    } catch (_) {
      if (mounted) setState(() => _pollFailed = true);
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final showResult = order != null && order.status.isFinal && order.status != OrderStatus.done;
    return NursePage(
      step: 4,
      spacingReferenceHeight: showResult ? _resultSpacingReferenceHeight : AppScale.referenceHeight,
      builder: (context, scale) {
        if (order == null) {
          return _pollFailed
              ? Center(child: AppAlert(message: 'Connection lost. Trying again…', scale: scale))
              : const Center(child: CircularProgressIndicator());
        }
        return showResult ? _buildResult(order, scale) : _buildPreparing(order, scale);
      },
    );
  }

  /// The demo controls, only in demo mode and only when the service offers them (the mock).
  DemoControls? get _demoControls {
    final api = context.read<ApiService>();
    return AppConfig.demoMode && api is DemoControls ? api as DemoControls : null;
  }

  // ------------------------------------------------------------------ preparing

  Widget _buildPreparing(Order order, AppScale scale) {
    final progress = OrderProgress.from(order);
    final current = progress.current;
    final stage = order.status == OrderStatus.pending ? 0 : (current == null ? 2 : 1);
    final seconds = math.max(1, progress.unitsLeft * AppConfig.estimatedSecondsPerUnit);

    final cabinet = CabinetDiagram(
      slotCount: math.max(AppConfig.cabinetSlots, order.items.map((l) => l.slotNumber).fold(0, math.max)),
      activeSlot: current?.slotNumber,
      finishedSlots: progress.finishedSlots,
      scale: scale,
    );
    final demo = _demoControls;
    final action = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCurrentAction(progress, scale),
        if (demo != null && order.status == OrderStatus.dispensing && current != null) ...[
          SizedBox(height: scale.size(AppSpacing.gapS)),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: _faultSimulated ? 'Robot fault simulated' : 'Simulate robot fault',
              variant: AppButtonVariant.ghost,
              onPressed: _faultSimulated
                  ? null
                  : () {
                      demo.simulateArmFault(order.id);
                      setState(() => _faultSimulated = true);
                    },
              height: scale.buttonHeight,
              textStyle: scale.text(AppText.small.copyWith(fontSize: 14)),
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PLEASE WAIT NEARBY', style: scale.text(AppText.eyebrow)),
                  SizedBox(height: scale.size(AppSpacing.gapXs)),
                  Text('Preparing your request', style: scale.h1),
                  SizedBox(height: scale.size(AppSpacing.gapS)),
                  Text('The cabinet is retrieving and packing your supplies.', style: scale.bodyMuted),
                ],
              ),
            ),
            if (current != null) StatusChip(label: 'About $seconds sec', tone: ChipTone.teal, scale: scale),
          ],
        ),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        WorkingSteps(stages: _stages, current: stage, scale: scale),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        if (_pollFailed)
          AppAlert(
            message: 'Connection lost. Trying again…',
            scale: scale,
            margin: EdgeInsets.only(bottom: scale.size(AppSpacing.gapL)),
          ),
        // Cabinet and "Now working" side by side (.robot-content 1.35fr 1fr), stacked when narrow.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gap = scale.size(AppSpacing.robotContentGap);
              if (constraints.maxWidth < AppSpacing.twoColBreakpoint) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: cabinet), SizedBox(height: gap), action],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 135, child: cabinet),
                  SizedBox(width: gap),
                  Expanded(flex: 100, child: Center(child: action)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// "Now working" panel (.current-action): which item, which slot, units picked.
  Widget _buildCurrentAction(OrderProgress progress, AppScale scale) {
    final current = progress.current;
    final small = scale.text(AppText.small.copyWith(fontSize: 14)).copyWith(color: AppColors.text);
    return Container(
      padding: EdgeInsets.all(scale.size(AppSpacing.currentActionPadding)),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: scale.size(4)),
            width: scale.size(AppSpacing.pulseDotSize),
            height: scale.size(AppSpacing.pulseDotSize),
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
          SizedBox(width: scale.size(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Now working', style: small.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                SizedBox(height: scale.size(5)),
                Text(
                  current == null ? 'All items picked' : 'Item ${progress.currentNumber} of ${progress.itemCount}',
                  style: scale.strong,
                ),
                SizedBox(height: scale.size(5)),
                Text(
                  current == null ? 'Finishing up…' : 'Moving to slot ${current.slotNumber} · ${current.name}',
                  style: small,
                ),
                SizedBox(height: scale.size(AppSpacing.gapM)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: scale.size(8),
                    color: AppColors.primary,
                    backgroundColor: AppColors.card,
                  ),
                ),
                SizedBox(height: scale.size(AppSpacing.gapXs)),
                Text('${progress.unitsPicked} of ${progress.totalUnits} units picked', style: small),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ result (PARTIAL / FAILED)

  Widget _buildResult(Order order, AppScale scale) {
    final partial = order.status == OrderStatus.partial;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusChip(
          label: partial ? 'Partly dispensed' : 'Not dispensed',
          tone: partial ? ChipTone.warning : ChipTone.error,
          scale: scale,
        ),
        SizedBox(height: scale.size(AppSpacing.gapS)),
        Text(partial ? 'Some items could not be dispensed' : 'Your request could not be dispensed', style: scale.h1),
        SizedBox(height: scale.size(AppSpacing.gapS)),
        Text(
          partial
              ? 'Collect the items that were dispensed. The missing items are recorded.'
              : 'Nothing was picked. Your request is recorded. Report the problem or start a new request.',
          style: scale.bodyMuted,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (partial)
          heading
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _faultIcon(scale),
              SizedBox(width: scale.size(AppSpacing.gapXl)),
              Expanded(child: heading),
            ],
          ),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        Flexible(
          child: OrderLineList(
            key: const Key('result-list'),
            rows: [for (final line in order.items) _resultRow(line, scale)],
          ),
        ),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        if (partial)
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Collect available items',
              onPressed: () => context.go('/collect/${order.id}'),
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
          )
        else
          // FAILED: name what is missing and offer "Report problem" (PARTIAL reports on Collect).
          ProblemReportPanel(
            order: order,
            scale: scale,
            actions: [
              AppButton(
                label: 'Start a new request',
                onPressed: () => context.go('/patient'),
                height: scale.buttonHeight,
                textStyle: scale.button,
              ),
            ],
          ),
      ],
    );
  }

  /// Red "!" circle (.fault-icon).
  Widget _faultIcon(AppScale scale) {
    final size = scale.size(AppSpacing.faultIconSize);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.errorBg, shape: BoxShape.circle),
      child: Text('!', style: scale.text(AppText.h1.copyWith(fontSize: 35, color: AppColors.error))),
    );
  }

  /// "2 of 3" and a chip: Dispensed, Partly or Not dispensed.
  Widget _resultRow(OrderItem line, AppScale scale) => OrderLineRow(
        name: line.name,
        slotNumber: line.slotNumber,
        quantity: '${line.qtyDispensed} of ${line.qtyRequested}',
        status: dispenseResultChip(line, scale),
        scale: scale,
      );
}
