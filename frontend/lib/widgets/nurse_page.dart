import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import 'step_tracker.dart';
import 'top_bar.dart';

/// Layout shared by every signed-in nurse screen (prototype: NurseShell + .main-card):
/// top bar, step tracker, then one white card that fills the rest of the window.
///
/// The card's content gets an [AppScale] worked out from the window height, so the
/// screen fits without scrolling and grows on tall windows. Only on very small
/// windows (below [AppScale.minFitHeight]) does the page scroll, as a safety net.
class NursePage extends StatelessWidget {
  /// Index in [StepTracker.steps] of this screen.
  final int step;

  /// Builds what goes inside the card. The child always gets a bounded height,
  /// so it can use Expanded/Flexible to fill the card.
  final Widget Function(BuildContext context, AppScale scale) builder;

  const NursePage({super.key, required this.step, required this.builder});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    if (user == null) return const SizedBox.shrink(); // the router sends us back to /login

    void signOut() {
      context.read<ApiService>().signOut();
      context.read<AuthState>().signOut(); // the router then sends us to /login
    }

    final window = MediaQuery.sizeOf(context);
    final available = window.height - AppSpacing.topBarHeight - AppSpacing.stepTrackerHeight;
    final scale = AppScale.forHeight(available);
    final narrow = window.width < AppSpacing.compactBreakpoint;

    final body = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? AppSpacing.mobileGutter : AppSpacing.pagePaddingX,
        vertical: scale.size(AppSpacing.pagePaddingY),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.mainCardMaxWidth),
          child: Container(
            key: const Key('nurse-page-card'),
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.all(scale.size(narrow ? AppSpacing.gapXxl : AppSpacing.cardPadding)),
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

    return Scaffold(
      body: Column(
        children: [
          TopBar(user: user, onSignOut: signOut),
          StepTracker(current: step, scale: scale),
          Expanded(
            child: available >= AppScale.minFitHeight
                ? body
                : SingleChildScrollView(child: SizedBox(height: AppScale.minFitHeight, child: body)),
          ),
        ],
      ),
    );
  }
}
