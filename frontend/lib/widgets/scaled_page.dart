import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import 'step_tracker.dart';

/// Page layout used by every screen: a top bar, an optional step tracker, then one white
/// card that fills the rest of the window (prototype: .nurse-main / .auth-wrap + .main-card).
///
/// The card's content gets an [AppScale] worked out from the window height, so the screen
/// fits without scrolling and grows on tall windows. Only below [minFitHeight] does the
/// page scroll, as a safety net for very small windows.
class ScaledPage extends StatelessWidget {
  final Widget topBar;

  /// Index in [StepTracker.steps] of this screen, or null for no step tracker (login).
  final int? step;

  /// False: no page padding and no card; the content fills the whole area edge to edge
  /// (Supplies, prototype .supply-layout).
  final bool withCard;

  /// Prototype sizes of the card; the padding is scaled.
  final double cardMaxWidth;
  final double cardPaddingX;
  final double cardPaddingY;

  /// See [AppScale.forHeight].
  final double spacingReferenceHeight;

  /// Smallest height of the area below the top bar (and step tracker) that the content fits in.
  final double minFitHeight;

  /// Builds what goes inside the card (or the whole area without a card). The child always gets a bounded height,
  /// so it can use Expanded/Flexible to fill the card.
  final Widget Function(BuildContext context, AppScale scale) builder;

  const ScaledPage({
    super.key,
    required this.topBar,
    this.step,
    this.withCard = true,
    this.cardMaxWidth = AppSpacing.mainCardMaxWidth,
    this.cardPaddingX = AppSpacing.cardPadding,
    this.cardPaddingY = AppSpacing.cardPadding,
    this.spacingReferenceHeight = AppScale.referenceHeight,
    this.minFitHeight = AppScale.minFitHeight,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    // Always measured below the top bar AND the step tracker, even when there is no
    // tracker (login), so the same window gives the same text size on every screen.
    final scale = AppScale.forHeight(
      window.height - AppSpacing.topBarHeight - AppSpacing.stepTrackerHeight,
      spacingReferenceHeight: spacingReferenceHeight,
    );
    final bodyHeight = window.height - AppSpacing.topBarHeight - (step == null ? 0 : AppSpacing.stepTrackerHeight);
    final narrow = window.width < AppSpacing.compactBreakpoint;

    final Widget body;
    if (!withCard) {
      body = builder(context, scale);
    } else {
      body = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: narrow ? AppSpacing.mobileGutter : AppSpacing.pagePaddingX,
          vertical: scale.size(AppSpacing.pagePaddingY),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cardMaxWidth),
            child: Container(
              key: const Key('page-card'),
              width: double.infinity,
              height: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: scale.size(narrow ? AppSpacing.gapXxl : cardPaddingX),
                vertical: scale.size(narrow ? AppSpacing.gapXxl : cardPaddingY),
              ),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, offset: Offset(0, 6))],
              ),
              child: builder(context, scale),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          topBar,
          if (step != null) StepTracker(current: step!, scale: scale),
          Expanded(
            child: bodyHeight >= minFitHeight
                ? body
                : SingleChildScrollView(child: SizedBox(height: minFitHeight, child: body)),
          ),
        ],
      ),
    );
  }
}
