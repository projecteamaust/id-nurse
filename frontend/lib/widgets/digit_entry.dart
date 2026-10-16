import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'keypad.dart';

/// "ID number" field + keypad + submit button (.digit-entry).
/// Used for the staff ID now, and for the patient file number later.
/// The number can be typed on a keyboard or with the on-screen keypad.
class DigitEntry extends StatelessWidget {
  final TextEditingController controller;
  final int minLength;
  final int maxLength;
  final String buttonLabel;
  final VoidCallback onSubmit;
  final bool hasError; // red border when the last attempt failed
  final bool busy; // disables everything while a request runs
  final bool dense; // smaller field, keypad and gaps for short screens

  const DigitEntry({
    super.key,
    required this.controller,
    required this.minLength,
    required this.maxLength,
    required this.buttonLabel,
    required this.onSubmit,
    this.hasError = false,
    this.busy = false,
    this.dense = false,
  });

  void _set(String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = dense ? AppSpacing.keypadGap : AppSpacing.gapL;
    final fieldPaddingY = dense ? AppSpacing.fieldPaddingYShort : AppSpacing.fieldPaddingY;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.digitEntryMaxWidth),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSubmit = !busy && value.text.length >= minLength;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ID number', style: AppText.label),
                SizedBox(height: dense ? AppSpacing.gapXs : AppSpacing.gapS),
                TextField(
                  key: const Key('digit-entry-field'),
                  controller: controller,
                  enabled: !busy,
                  textAlign: TextAlign.center,
                  style: AppText.digitInput,
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
                Keypad(
                  enabled: !busy,
                  buttonHeight: dense ? AppSpacing.keypadButtonHeightShort : AppSpacing.keypadButtonHeight,
                  gap: dense ? AppSpacing.keypadGapShort : AppSpacing.keypadGap,
                  onDigit: (d) {
                    if (value.text.length < maxLength) _set(value.text + d);
                  },
                  onClear: () => _set(''),
                  onBack: () {
                    if (value.text.isNotEmpty) _set(value.text.substring(0, value.text.length - 1));
                  },
                ),
                SizedBox(height: gap),
                AppButton(label: buttonLabel, onPressed: canSubmit ? onSubmit : null, expand: true),
              ],
            );
          },
        ),
      ),
    );
  }
}
