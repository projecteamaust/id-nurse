import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// The 48 px progress bar under the top bar (.step-tracker).
/// Steps up to and including [current] are teal; later steps are grey.
/// The bar keeps its 48 px height; only the step names scale.
class StepTracker extends StatelessWidget {
  static const steps = ['Identify', 'Patient', 'Supplies', 'Review', 'Prepare', 'Collect', 'Complete'];

  /// Index in [steps] of the screen being shown (0 = Identify).
  final int current;
  final AppScale scale;

  const StepTracker({super.key, required this.current, this.scale = AppScale.none});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    return Container(
      height: AppSpacing.stepTrackerHeight,
      padding: EdgeInsets.symmetric(horizontal: compact ? AppSpacing.mobileGutter : AppSpacing.pagePaddingX),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(child: _Step(label: steps[i], active: i <= current, last: i == steps.length - 1, scale: scale)),
        ],
      ),
    );
  }
}

/// One step: dot, name, then a line to the next step (.step, .step i, .step::after).
class _Step extends StatelessWidget {
  final String label;
  final bool active;
  final bool last;
  final AppScale scale;

  const _Step({required this.label, required this.active, required this.last, required this.scale});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.border;
    return Row(
      children: [
        Container(
          width: AppSpacing.stepDotSize,
          height: AppSpacing.stepDotSize,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: active ? AppColors.primary : AppColors.stepDot, width: 2),
          ),
        ),
        const SizedBox(width: AppSpacing.gapS),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: scale.text(
              active ? AppText.step.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600) : AppText.step,
            ),
          ),
        ),
        if (!last) ...[
          const SizedBox(width: AppSpacing.gapS),
          Expanded(child: Container(height: 2, color: color)),
          const SizedBox(width: AppSpacing.gapS),
        ],
      ],
    );
  }
}
