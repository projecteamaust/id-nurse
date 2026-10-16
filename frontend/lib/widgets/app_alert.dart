import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

enum AlertTone { warning, error, success }

/// Colored message box (.alert-warning / .alert-error / .alert-success).
class AppAlert extends StatelessWidget {
  final String message;
  final AlertTone tone;
  final EdgeInsetsGeometry margin;

  const AppAlert({
    super.key,
    required this.message,
    this.tone = AlertTone.warning,
    this.margin = const EdgeInsets.symmetric(vertical: AppSpacing.gapL),
  });

  @override
  Widget build(BuildContext context) {
    final (Color text, Color background, Color border) = switch (tone) {
      AlertTone.warning => (AppColors.alertWarningText, AppColors.warningBg, AppColors.alertWarningBorder),
      AlertTone.error => (AppColors.error, AppColors.dangerBg, AppColors.alertErrorBorder),
      AlertTone.success => (AppColors.alertSuccessText, AppColors.successBg, AppColors.alertSuccessBorder),
    };
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      ),
      child: Text(message, style: AppText.body.copyWith(color: text, height: 1.4)),
    );
  }
}
