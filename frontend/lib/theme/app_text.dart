import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Font and text styles. Copied from design/prototype/src/index.css.
/// letterSpacing in CSS is in em, so we multiply by the font size.
class AppText {
  AppText._();

  static const fontFamily = 'IBM Plex Sans';
  static const double baseSize = 18; // :root { font-size: 18px }

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: baseSize,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
    height: 1.5,
  );

  /// Paragraph text under headings (p { color: muted }).
  static final bodyMuted = body.copyWith(color: AppColors.muted);

  static const h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.02 * 32,
    height: 1.2,
    color: AppColors.text,
  );

  static const h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.text,
  );

  static const h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  /// Logo text "ID Nurse" (.brand)
  static const brand = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: baseSize,
    fontWeight: FontWeight.w600,
  );

  static const keypadButton = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  static const strong = TextStyle(
    fontFamily: fontFamily,
    fontSize: baseSize,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  /// Form labels (.field)
  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: baseSize,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  /// The big digit input (.digit-entry input)
  static const digitInput = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    letterSpacing: 0.14 * 28,
    color: AppColors.text,
  );

  /// Small uppercase label above headings (.eyebrow)
  static const eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.08 * 13,
    color: AppColors.primary,
  );

  static const chip = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const tableHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    color: AppColors.muted,
  );

  static const statNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 31,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  /// Name/ward block in the top bar (.identity)
  static const identity = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    color: AppColors.text,
  );
}
