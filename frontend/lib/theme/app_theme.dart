import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// The app-wide Material theme, built only from AppColors, AppText and AppSpacing.
ThemeData buildAppTheme() {
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
  );
  const buttonSize = Size(0, AppSpacing.buttonHeight);
  const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.buttonPaddingX);

  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppText.fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.text,
      error: AppColors.error,
    ),
    textTheme: TextTheme(
      headlineLarge: AppText.h1,
      headlineMedium: AppText.h2,
      headlineSmall: AppText.h3,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      labelLarge: AppText.button,
    ),
    // Primary button (.btn-primary)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: AppText.button,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.primary.withValues(alpha: 0.43);
          }
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) {
            return AppColors.primaryDark;
          }
          return AppColors.primary;
        }),
      ),
    ),
    // Secondary button (.btn-secondary)
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: AppText.button,
      ),
    ),
    // Ghost button (.btn-ghost)
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: AppText.button,
      ),
    ),
    // Text inputs (.field input)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder(AppColors.border),
      enabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.primary, 2),
      errorBorder: inputBorder(AppColors.error),
      focusedErrorBorder: inputBorder(AppColors.error, 2),
      // Placeholders use the normal text style (inputs inherit the body font in the prototype).
      // DigitEntry sets its own wide-spaced hint (.digit-entry input).
      hintStyle: AppText.bodyMuted,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.toast,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontFamily: AppText.fontFamily, color: Colors.white, fontSize: 16),
    ),
    dividerColor: AppColors.border,
  );
}
