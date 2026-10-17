import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// Number keypad: 1-9, Clear, 0, Back (.keypad). 3 columns, 64 px buttons.
///
/// With [fill] the buttons share the height the keypad is given (between
/// [AppSpacing.keypadButtonMinHeight] and [AppSpacing.keypadButtonMaxHeight])
/// instead of using [buttonHeight].
class Keypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final bool enabled;
  final double buttonHeight;
  final double gap;
  final bool fill;
  final TextStyle textStyle;

  const Keypad({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onBack,
    this.enabled = true,
    this.buttonHeight = AppSpacing.keypadButtonHeight,
    this.gap = AppSpacing.keypadGap,
    this.fill = false,
    this.textStyle = AppText.keypadButton,
  });

  @override
  Widget build(BuildContext context) {
    if (!fill) return _buildKeys(buttonHeight);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = ((constraints.maxHeight - 3 * gap) / 4)
            .clamp(AppSpacing.keypadButtonMinHeight, AppSpacing.keypadButtonMaxHeight);
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
