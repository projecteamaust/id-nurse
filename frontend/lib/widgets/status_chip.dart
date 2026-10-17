import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// The color variants of .chip, .chip-success, .chip-warning, .chip-error and .chip-teal.
enum ChipTone { neutral, success, warning, error, teal }

/// Small rounded label (.chip): 12 px bold text, at least 28 px tall, fully rounded.
class StatusChip extends StatelessWidget {
  final String label;
  final ChipTone tone;
  final AppScale scale;

  const StatusChip({super.key, required this.label, this.tone = ChipTone.neutral, this.scale = AppScale.none});

  @override
  Widget build(BuildContext context) {
    final (Color background, Color text) = switch (tone) {
      ChipTone.neutral => (AppColors.neutralChip, AppColors.muted),
      ChipTone.success => (AppColors.successBg, AppColors.success),
      ChipTone.warning => (AppColors.warningBg, AppColors.warning),
      ChipTone.error => (AppColors.errorBg, AppColors.error),
      ChipTone.teal => (AppColors.primaryLight, AppColors.primaryDark),
    };
    return Container(
      constraints: BoxConstraints(minHeight: scale.size(AppSpacing.chipHeight)),
      padding: EdgeInsets.symmetric(horizontal: scale.size(10), vertical: scale.size(4)),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: scale.text(AppText.chip).copyWith(color: text)),
    );
  }
}
