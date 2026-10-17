import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Row of numbered stages joined by lines (.working-steps). Stages before [current]
/// show ✓; [current] is teal; later ones are grey.
class WorkingSteps extends StatelessWidget {
  final List<String> stages;
  final int current;
  final AppScale scale;

  const WorkingSteps({super.key, required this.stages, required this.current, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stages.length; i++)
          Expanded(child: _stage(i, last: i == stages.length - 1)),
      ],
    );
  }

  Widget _stage(int i, {required bool last}) {
    final done = i < current;
    final active = i <= current;
    final dot = scale.size(AppSpacing.stageDotSize);
    return Row(
      children: [
        Container(
          width: dot,
          height: dot,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primary : AppColors.card,
            border: Border.all(color: active ? AppColors.primary : AppColors.border, width: 2),
          ),
          child: Text(
            done ? '✓' : '${i + 1}',
            style: scale.text(AppText.chip).copyWith(color: active ? Colors.white : AppColors.stageInactive),
          ),
        ),
        SizedBox(width: scale.size(AppSpacing.gapS)),
        Flexible(
          child: Text(
            stages[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: scale.text(AppText.small.copyWith(fontSize: 14)).copyWith(
              color: active ? AppColors.primary : AppColors.stageInactive,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (!last) ...[
          SizedBox(width: scale.size(AppSpacing.gapS)),
          Expanded(child: Container(height: 2, color: done ? AppColors.primary : AppColors.border)),
          SizedBox(width: scale.size(AppSpacing.gapS)),
        ],
      ],
    );
  }
}
