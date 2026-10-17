import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Green ✓ circle (.ready-icon, .complete-head > span). Used by Collect and Complete.
class SuccessBadge extends StatelessWidget {
  final AppScale scale;

  const SuccessBadge({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final size = scale.size(AppSpacing.readyIconSize);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
      child: Text('✓', style: scale.text(AppText.h1.copyWith(color: AppColors.success, fontWeight: FontWeight.w700))),
    );
  }
}
