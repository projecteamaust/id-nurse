import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'keypad.dart';

/// Number field + keypad + submit button (.digit-entry).
/// Used for the staff ID (login) and the patient file number.
/// The number can be typed on a keyboard or with the on-screen keypad.
///
/// Two ways to size it:
/// - give a [scale]: it fills the height it is given (the keypad takes the free space)
///   and uses scaled text and gaps. It must then have a bounded height.
/// - no [scale] (login for now): prototype sizes, with [dense] for short screens.
class DigitEntry extends StatelessWidget {
  final TextEditingController controller;
  final String label; // text above the field
  final int minLength;
  final int maxLength;
  final String buttonLabel;
  final VoidCallback onSubmit;
  final bool hasError; // red border when the last attempt failed
  final bool busy; // disables everything while a request runs
  final bool dense; // smaller field, keypad and gaps for short screens
  final AppScale? scale; // fill the height and scale with it

  const DigitEntry({
    super.key,
    required this.controller,
    this.label = 'ID number',
    required this.minLength,
    required this.maxLength,
    required this.buttonLabel,
    required this.onSubmit,
    this.hasError = false,
    this.busy = false,
    this.dense = false,
    this.scale,
  });

  void _set(String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final fill = s != null;
    final gap = s?.size(AppSpacing.gapL) ?? (dense ? AppSpacing.keypadGap : AppSpacing.gapL);
    final labelGap = s?.size(AppSpacing.gapS) ?? (dense ? AppSpacing.gapXs : AppSpacing.gapS);
    final fieldPaddingY = s?.size(AppSpacing.fieldPaddingY) ??
        (dense ? AppSpacing.fieldPaddingYShort : AppSpacing.fieldPaddingY);
    final keypad = Keypad(
      enabled: !busy,
      fill: fill,
      buttonHeight: dense ? AppSpacing.keypadButtonHeightShort : AppSpacing.keypadButtonHeight,
      gap: s?.size(AppSpacing.keypadGap) ?? (dense ? AppSpacing.keypadGapShort : AppSpacing.keypadGap),
      textStyle: s?.text(AppText.keypadButton) ?? AppText.keypadButton,
      onDigit: (d) {
        if (controller.text.length < maxLength) _set(controller.text + d);
      },
      onClear: () => _set(''),
      onBack: () {
        final text = controller.text;
        if (text.isNotEmpty) _set(text.substring(0, text.length - 1));
      },
    );
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: s?.size(AppSpacing.digitEntryMaxWidth) ?? AppSpacing.digitEntryMaxWidth),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSubmit = !busy && value.text.length >= minLength;
            // In fill mode the column only takes the height it needs (the keypad grows
            // up to its maximum button height) and Center puts it in the middle.
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: s?.label ?? AppText.label),
                SizedBox(height: labelGap),
                TextField(
                  key: const Key('digit-entry-field'),
                  controller: controller,
                  enabled: !busy,
                  textAlign: TextAlign.center,
                  style: s?.text(AppText.digitInput) ?? AppText.digitInput,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
                  onSubmitted: (_) => canSubmit ? onSubmit() : null,
                  decoration: InputDecoration(
                    hintText: '_ _ _ _ _ _',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: fieldPaddingY),
                    enabledBorder: hasError
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                            borderSide: const BorderSide(color: AppColors.error),
                          )
                        : null,
                  ),
                ),
                SizedBox(height: gap),
                if (fill) Flexible(child: keypad) else keypad,
                SizedBox(height: gap),
                AppButton(
                  label: buttonLabel,
                  onPressed: canSubmit ? onSubmit : null,
                  expand: true,
                  height: s?.buttonHeight ?? AppSpacing.buttonHeight,
                  textStyle: s?.button,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
