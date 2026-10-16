import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// Number keypad: 1-9, Clear, 0, Back (.keypad). 3 columns, 64 px buttons.
class Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final bool enabled;

  const Keypad({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onBack,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback action) => AppButton(
          label: label,
          variant: AppButtonVariant.secondary,
          height: AppSpacing.keypadButtonHeight,
          textStyle: AppText.keypadButton,
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
              if (i > 0) const SizedBox(width: AppSpacing.keypadGap),
              Expanded(child: keys[i]),
            ],
          ],
        );

    return Semantics(
      label: 'Numeric keypad',
      child: Column(
        children: [
          for (final digits in rows) ...[
            row([for (final d in digits) key(d, () => onDigit(d))]),
            const SizedBox(height: AppSpacing.keypadGap),
          ],
          row([key('Clear', onClear), key('0', () => onDigit('0')), key('Back', onBack)]),
        ],
      ),
    );
  }
}
