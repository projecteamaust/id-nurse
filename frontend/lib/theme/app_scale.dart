import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'app_spacing.dart';
import 'app_text.dart';

/// Makes a screen grow and shrink with the window height (rule: every screen fits the
/// window without scrolling). The prototype sizes are used as-is at the reference height
/// and multiplied by a factor elsewhere, within limits so nothing gets too big or too small.
class AppScale {
  /// Space below the top bar and step tracker on a 1280x800 window (800 - 80 - 48).
  /// At this height text is the prototype size on every screen, and so is the spacing
  /// on screens that don't give their own spacing reference.
  static const double referenceHeight = 672;

  /// Limits for spacing and sizes. The low limit is well below 1 because screens with a
  /// lot of content in one column (Login) must tighten their gaps on short windows.
  static const double minFactor = 0.6;
  static const double maxFactor = 1.25;

  /// Limits for text. Narrower than spacing so text always stays readable.
  static const double minTextFactor = 0.9;
  static const double maxTextFactor = 1.2;

  /// Buttons, tabs and keypad keys never get smaller than this (Flutter's minimum touch size).
  static const double minTouchHeight = 48;

  /// Below this available height a screen scrolls instead of squeezing its content.
  static const double minFitHeight = 520;

  /// Multiplier for spacing and sizes.
  final double factor;

  /// Multiplier for font sizes.
  final double textFactor;

  const AppScale._(this.factor, this.textFactor);

  /// No scaling: the prototype sizes.
  static const none = AppScale._(1, 1);

  /// Scale for a screen whose content area is [availableHeight] pixels tall.
  ///
  /// [spacingReferenceHeight] is the height at which this screen's spacing is the
  /// prototype size. A screen with more content uses a larger value, so its spacing
  /// shrinks sooner. Text always uses [referenceHeight], so it is the same size on
  /// every screen in the same window.
  factory AppScale.forHeight(double availableHeight, {double spacingReferenceHeight = referenceHeight}) {
    return AppScale._(
      (availableHeight / spacingReferenceHeight).clamp(minFactor, maxFactor),
      (availableHeight / referenceHeight).clamp(minTextFactor, maxTextFactor),
    );
  }

  /// A size or gap from the prototype, scaled.
  double size(double prototypeValue) => prototypeValue * factor;

  /// Height of something you tap (button, tab, key), scaled but never below [minTouchHeight].
  double control(double prototypeHeight) => math.max(minTouchHeight, size(prototypeHeight));

  /// Any text style with its font size (and letter spacing) scaled.
  TextStyle text(TextStyle style) => style.copyWith(
        fontSize: (style.fontSize ?? AppText.baseSize) * textFactor,
        letterSpacing: style.letterSpacing == null ? null : style.letterSpacing! * textFactor,
      );

  // Shortcuts for the styles screens use most.
  TextStyle get h1 => text(AppText.h1);
  TextStyle get body => text(AppText.body);
  TextStyle get bodyMuted => text(AppText.bodyMuted);
  TextStyle get strong => text(AppText.strong);
  TextStyle get small => text(AppText.small);
  TextStyle get label => text(AppText.label);
  TextStyle get button => text(AppText.button);

  double get buttonHeight => control(AppSpacing.buttonHeight);
}
