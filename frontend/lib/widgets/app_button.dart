import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// The four button styles from the prototype (.btn-primary, -secondary, -danger, -ghost).
enum AppButtonVariant { primary, secondary, danger, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed; // null = disabled
  final AppButtonVariant variant;
  final double height;
  final TextStyle? textStyle;
  final bool expand; // fill the available width
  final EdgeInsetsGeometry? padding; // null = theme padding (0 24 px)

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.height = AppSpacing.buttonHeight,
    this.textStyle,
    this.expand = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final size = Size(expand ? double.infinity : 0, height);
    final text = Text(label, style: textStyle, maxLines: 1, softWrap: false);
    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: size, padding: padding),
          child: text,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(minimumSize: size, padding: padding),
          child: text,
        ),
      AppButtonVariant.danger => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            padding: padding,
            foregroundColor: AppColors.error,
            backgroundColor: AppColors.dangerBg,
            side: const BorderSide(color: AppColors.dangerBorder),
          ),
          child: text,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(minimumSize: size, padding: padding),
          child: text,
        ),
    };
    // Disabled buttons fade to 43% like `.btn:disabled`.
    return Opacity(
      opacity: onPressed == null && variant != AppButtonVariant.primary ? 0.43 : 1,
      child: DefaultTextStyle.merge(style: AppText.button, child: button),
    );
  }
}
