import 'package:flutter/material.dart';

import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// Number keypad: 1-9, Clear, 0, Back (.keypad). 3 columns, 4 rows.
///
/// The buttons share the height the keypad is given, between [AppScale.minTouchHeight]
/// and [AppSpacing.keypadButtonMaxHeight] (the prototype uses 64 px).
class Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final bool enabled;
  final double gap;
  final TextStyle textStyle;

  const Keypad({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onBack,
    this.enabled = true,
    this.gap = AppSpacing.keypadGap,
    this.textStyle = AppText.keypadButton,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = ((constraints.maxHeight - 3 * gap) / 4)
            .clamp(AppScale.minTouchHeight, AppSpacing.keypadButtonMaxHeight);
        return _buildKeys(height);
      },
    );
  }

  Widget _buildKeys(double height) {
    Widget key(String label, VoidCallback action) => AppButton(
          label: label,
          variant: AppButtonVariant.secondary,
          height: height,
          textStyle: textStyle,
          expand: true,
          onPressed: enabled ? action : null,
        );

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    Widget row(List<Widget> keys) => Row(
          children: [
            for (var i = 0; i < keys.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: keys[i]),
            ],
          ],
        );

    return Semantics(
      label: 'Numeric keypad',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final digits in rows) ...[
            row([for (final d in digits) key(d, () => onDigit(d))]),
            SizedBox(height: gap),
          ],
          row([key('Clear', onClear), key('0', () => onDigit('0')), key('Back', onBack)]),
        ],
      ),
    );
  }
}
