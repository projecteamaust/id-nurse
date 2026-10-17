import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../services/order_draft.dart';
import '../theme/app_scale.dart';
import 'scaled_page.dart';
import 'top_bar.dart';

/// Layout shared by every signed-in nurse screen (prototype: NurseShell + .main-card):
/// top bar with the nurse and "Sign out", step tracker, then a [ScaledPage] card
/// that fills the rest of the window.
class NursePage extends StatelessWidget {
  /// Index in [StepTracker.steps] of this screen.
  final int step;

  /// See [ScaledPage.withCard].
  final bool withCard;

  /// Builds what goes inside the card (see [ScaledPage.builder]).
  final Widget Function(BuildContext context, AppScale scale) builder;

  const NursePage({super.key, required this.step, this.withCard = true, required this.builder});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    if (user == null) return const SizedBox.shrink(); // the router sends us back to /login

    void signOut() {
      context.read<ApiService>().signOut();
      context.read<OrderDraft>().clear(); // forget the patient and the request
      context.read<AuthState>().signOut(); // the router then sends us to /login
    }

    return ScaledPage(
      topBar: TopBar(user: user, onSignOut: signOut),
      step: step,
      withCard: withCard,
      builder: builder,
    );
  }
}
