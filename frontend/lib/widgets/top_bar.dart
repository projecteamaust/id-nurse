import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_logo.dart';

/// The 80 px header on every screen (.topbar).
/// Signed in: name, ward and "Sign out". Signed out: optional "Admin sign in".
class TopBar extends StatelessWidget {
  final User? user;
  final VoidCallback? onSignOut;
  final VoidCallback? onAdmin;

  const TopBar({super.key, this.user, this.onSignOut, this.onAdmin});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    return Container(
      height: AppSpacing.topBarHeight,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.mobileGutter : AppSpacing.topBarPaddingX,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const AppLogo(),
          const Spacer(),
          if (user != null) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(user!.name, style: AppText.identity.copyWith(fontWeight: FontWeight.w700)),
                Text(user!.ward, style: AppText.identity.copyWith(color: AppColors.muted)),
              ],
            ),
            const SizedBox(width: AppSpacing.gapM),
            AppButton(
              label: 'Sign out',
              variant: AppButtonVariant.secondary,
              onPressed: onSignOut,
            ),
          ] else if (onAdmin != null)
            AppButton(label: 'Admin sign in', variant: AppButtonVariant.ghost, onPressed: onAdmin),
        ],
      ),
    );
  }
}
