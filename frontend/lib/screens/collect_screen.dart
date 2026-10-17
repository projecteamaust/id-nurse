import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/nurse_page.dart';

/// TEMPORARY placeholder for step 6 (Collect). The Prepare screen already navigates here
/// on DONE (and from the PARTIAL result); the real Collect task replaces this screen.
class CollectScreen extends StatelessWidget {
  final int orderId;

  const CollectScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return NursePage(
      step: 5,
      builder: (context, scale) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('READY FOR COLLECTION', style: scale.text(AppText.eyebrow.copyWith(color: AppColors.success))),
          SizedBox(height: scale.size(AppSpacing.gapXs)),
          Text('Your items are ready', style: scale.h1),
          SizedBox(height: scale.size(AppSpacing.gapS)),
          Text('Take your items from the pickup box.', style: scale.bodyMuted),
          SizedBox(height: scale.size(AppSpacing.gapXxl)),
          AppButton(
            label: 'New request',
            onPressed: () => context.go('/patient'),
            height: scale.buttonHeight,
            textStyle: scale.button,
          ),
        ],
      ),
    );
  }
}
