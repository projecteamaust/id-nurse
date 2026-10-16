import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/top_bar.dart';

/// TEMPORARY: shown after a successful login until the "Is this you?" screen is built.
class SignedInPlaceholderScreen extends StatelessWidget {
  const SignedInPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink(); // the router sends us back to /login

    void signOut() {
      context.read<ApiService>().signOut();
      context.read<AuthState>().signOut();
    }

    return Scaffold(
      body: Column(
        children: [
          TopBar(user: user, onSignOut: signOut),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: AppSpacing.narrowCardMaxWidth),
                margin: const EdgeInsets.all(AppSpacing.mobileGutter),
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SIGNED IN', style: AppText.eyebrow),
                    const SizedBox(height: AppSpacing.gapXs),
                    Text('Signed in as ${user.name}', style: AppText.h1),
                    const SizedBox(height: AppSpacing.gapS),
                    Text('${user.ward} · Staff ID ${user.employeeId}', style: AppText.bodyMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
