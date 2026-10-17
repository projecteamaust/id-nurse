import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Teal rounded square with a white cross, plus "ID Nurse" (.brand / .logo-mark).
/// [textColor] is white on the dark supervisor sidebar.
class AppLogo extends StatelessWidget {
  final Color textColor;

  const AppLogo({super.key, this.textColor = AppColors.text});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          child: Stack(alignment: Alignment.center, children: [bar(22, 5), bar(5, 22)]),
        ),
        const SizedBox(width: AppSpacing.gapM),
        Text('ID Nurse', style: AppText.brand.copyWith(color: textColor)),
      ],
    );
  }
}
