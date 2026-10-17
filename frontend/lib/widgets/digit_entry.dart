import 'dart:math' as math;

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
/// It fills the height it is given (the keypad takes the free space, see [Keypad]) and
/// uses text and gaps from [scale], so it must be placed where its height is bounded.
class DigitEntry extends StatelessWidget {
  final TextEditingController controller;
  final String label; // text above the field
  final int minLength;
  final int maxLength;
  final String buttonLabel;
  final VoidCallback onSubmit;
  final bool hasError; // red border when the last attempt failed
  final bool busy; // disables everything while a request runs
  final AppScale scale;

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
    required this.scale,
  });

  void _set(String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = scale.size(AppSpacing.gapL);
    final keypad = Keypad(
      enabled: !busy,
      gap: scale.size(AppSpacing.keypadGap),
      textStyle: scale.text(AppText.keypadButton),
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
        // Grows on tall windows, but never narrower than the prototype's 430 px.
        constraints: BoxConstraints(
          maxWidth: math.max(AppSpacing.digitEntryMaxWidth, scale.size(AppSpacing.digitEntryMaxWidth)),
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSubmit = !busy && value.text.length >= minLength;
            // The column only takes the height it needs (the keypad grows up to its
            // maximum button height) and Center puts it in the middle.
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: scale.label),
                SizedBox(height: scale.size(AppSpacing.gapS)),
                TextField(
                  key: const Key('digit-entry-field'),
                  controller: controller,
                  enabled: !busy,
                  textAlign: TextAlign.center,
                  style: scale.text(AppText.digitInput),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
                  onSubmitted: (_) => canSubmit ? onSubmit() : null,
                  decoration: InputDecoration(
                    hintText: '_ _ _ _ _ _',
                    hintStyle: scale.text(AppText.digitInput).copyWith(color: AppColors.muted),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: scale.size(AppSpacing.fieldPaddingY)),
                    enabledBorder: hasError
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                            borderSide: const BorderSide(color: AppColors.error),
                          )
                        : null,
                  ),
                ),
                SizedBox(height: gap),
                Flexible(child: keypad),
                SizedBox(height: gap),
                AppButton(
                  label: buttonLabel,
                  onPressed: canSubmit ? onSubmit : null,
                  expand: true,
                  height: scale.buttonHeight,
                  textStyle: scale.button,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
