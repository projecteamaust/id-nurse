import 'package:flutter/painting.dart';

/// Every color used in the app. Copied from design/prototype/src/index.css.
/// Screens and widgets use these names and never write a hex value themselves.
class AppColors {
  AppColors._();

  // CSS variables (:root)
  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF0B5A54);
  static const primaryLight = Color(0xFFDDF1EE);
  static const background = Color(0xFFF3F7F6);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF12302D);
  static const muted = Color(0xFF5B7370);
  static const border = Color(0xFFD5E2DF);
  static const success = Color(0xFF15803D);
  static const successBg = Color(0xFFE7F7ED);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFEF3C7);
  static const error = Color(0xFFB91C1C);
  static const errorBg = Color(0xFFFEEAEA);

  // Hard-coded colors from index.css
  static const dangerBg = Color(0xFFFFF1F1); // .btn-danger, .alert-error
  static const dangerBorder = Color(0xFFF1C2C2); // .btn-danger
  static const neutralChip = Color(0xFFEDF2F1); // .chip
  static const surfaceSoft = Color(0xFFFBFDFC); // .profile-card, .patient-card
  static const tableHeader = Color(0xFFF7FAF9);
  static const supplyDisabledBg = Color(0xFFF8FAF9); // .supply-card.disabled
  static const supplyDisabledText = Color(0xFF7C918E);
  static const disabledStep = Color(0xFF8AA09D);
  static const stepDot = Color(0xFF9DB0AD);
  static const cabinet = Color(0xFFEDF3F2);
  static const cabinetBorder = Color(0xFFCADBD8);
  static const drawerBorder = Color(0xFFAAC2BE); // .drawer
  static const stageInactive = Color(0xFF93A5A2); // .working-steps > div
  static const doorOpen = Color(0xFF253C39);
  static const pickupBox = Color(0xFFE6EDEC); // .door (closed), used for the pickup box
  static const pickupBoxBorder = Color(0xFF99AEAB);
  static const toast = Color(0xFF12302D);
  static const adminSidebar = Color(0xFF102E2B);
  static const adminSidebarText = Color(0xFFB9CDCA);

  // Alert boxes (.alert-*)
  static const alertWarningText = Color(0xFF713F12);
  static const alertWarningBorder = Color(0xFFF8D675);
  static const alertErrorBorder = Color(0xFFF3B6B6);
  static const alertSuccessText = Color(0xFF12622F);
  static const alertSuccessBorder = Color(0xFFA8DAB9);

  // Soft card shadow: rgba(18,48,45,.04)
  static const cardShadow = Color(0x0A12302D);
}
