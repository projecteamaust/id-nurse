import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_alert.dart';

/// The frame of every dialog (.modal): white, rounded, at most 540 px wide.
/// Title, a muted line under it, the [content], an optional error, then the [actions]
/// right-aligned (usually Cancel and the main button).
/// Open it with `showDialog(barrierColor: AppColors.modalBackdrop, ...)`.
class AppDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget content;
  final String? error;
  final List<Widget> actions;
  final AppScale scale;

  const AppDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    this.error,
    required this.actions,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.modalMaxWidth),
        child: Padding(
          padding: EdgeInsets.all(scale.size(AppSpacing.modalPadding)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: scale.text(AppText.h2)),
              SizedBox(height: scale.size(AppSpacing.gapS)),
              Text(subtitle, style: scale.bodyMuted),
              SizedBox(height: scale.size(AppSpacing.modalHeadGap)),
              content,
              if (error != null)
                AppAlert(
                  message: error!,
                  tone: AlertTone.error,
                  scale: scale,
                  margin: EdgeInsets.only(top: scale.size(AppSpacing.gapS)),
                ),
              SizedBox(height: scale.size(AppSpacing.gapL)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) SizedBox(width: scale.size(AppSpacing.gapM)),
                    actions[i],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
