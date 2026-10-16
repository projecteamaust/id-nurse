import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The small ID card drawing on the Scan tab (.id-card-art).
/// While [reading] is true a teal line sweeps up and down over the card (.scan-line).
class IdCardArt extends StatefulWidget {
  final bool reading;

  const IdCardArt({super.key, required this.reading});

  @override
  State<IdCardArt> createState() => _IdCardArtState();
}

class _IdCardArtState extends State<IdCardArt> with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    if (widget.reading) _scan.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(IdCardArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reading && !_scan.isAnimating) {
      _scan.repeat(reverse: true);
    } else if (!widget.reading && _scan.isAnimating) {
      _scan.stop();
      _scan.value = 0;
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Card: 126 x 88, 3 px teal border. Inside (after the border): 120 x 82.
    Widget textLine(double top) => Positioned(
          left: 49,
          right: 11,
          top: top,
          child: Container(
            height: 7,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
          ),
        );

    return Container(
      width: 126,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.primary, width: 3),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall - 3),
        child: Stack(
          children: [
            Positioned(
              left: 13,
              top: 15,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              ),
            ),
            textLine(19),
            textLine(36),
            textLine(53),
            if (widget.reading)
              AnimatedBuilder(
                animation: _scan,
                builder: (context, _) => Positioned(
                  left: 2,
                  right: 2,
                  top: 2 + 72 * Curves.easeInOut.transform(_scan.value),
                  child: Container(height: 3, color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
