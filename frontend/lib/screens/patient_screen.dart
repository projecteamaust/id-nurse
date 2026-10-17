import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../services/api_service.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/digit_entry.dart';
import '../widgets/nurse_page.dart';
import '../widgets/patient_card.dart';

/// Step 2: "Which patient?" (prototype: screens "patient" and "confirm-patient" in App.tsx).
/// First the nurse types the file number on the keypad; after a successful lookup the
/// same screen shows the patient card so she can confirm it is the right patient.
/// The lookup goes through ApiService.getPatient; the screen never talks HTTP directly.
class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  static const _notFoundMessage = 'No patient with this file number. Check the number and try again.';
  static const _connectionMessage = 'Could not reach the server. Try again.';

  final _fileNumberController = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _failedNumber; // the number that caused [_error]
  Patient? _patient; // set after a successful lookup -> confirm state

  @override
  void initState() {
    super.initState();
    // Typing a different number hides the old error.
    _fileNumberController.addListener(() {
      if (_error != null && _fileNumberController.text != _failedNumber) {
        setState(() => _error = null);
      }
    });
  }

  @override
  void dispose() {
    _fileNumberController.dispose();
    super.dispose();
  }

  Future<void> _findPatient() async {
    if (_busy) return;
    final fileNumber = _fileNumberController.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final patient = await context.read<ApiService>().getPatient(fileNumber);
      if (!mounted) return;
      setState(() => _patient = patient);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404 ? _notFoundMessage : _connectionMessage;
        _failedNumber = fileNumber;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _connectionMessage;
        _failedNumber = fileNumber;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "No, enter again": back to an empty keypad.
  void _enterAgain() {
    _fileNumberController.clear();
    setState(() => _patient = null);
  }

  void _showSuppliesNotReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supply selection comes in a later step.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NursePage(
      step: 1,
      builder: (context, scale) => _patient == null ? _buildEntry(scale) : _buildConfirm(_patient!, scale),
    );
  }

  /// Heading + muted subtitle (.heading-group).
  Widget _heading(String title, String subtitle, AppScale scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: scale.h1),
        SizedBox(height: scale.size(AppSpacing.gapS)),
        Text(subtitle, style: scale.bodyMuted),
      ],
    );
  }

  /// "Which patient?": text on the left, keypad filling the right (.two-col-entry).
  /// Stacks into one column when the card is narrow; the keypad then fills the rest.
  Widget _buildEntry(AppScale scale) {
    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Which patient?', 'Enter the patient file number.', scale),
        SizedBox(height: scale.size(AppSpacing.gapS)),
        AppAlert(
          message: 'Patient details are used only for this supply request.',
          tone: AlertTone.success,
          scale: scale,
          margin: EdgeInsets.symmetric(vertical: scale.size(AppSpacing.gapL)),
        ),
        if (_error != null) AppAlert(message: _error!, tone: AlertTone.error, scale: scale, margin: EdgeInsets.zero),
      ],
    );
    final entry = DigitEntry(
      controller: _fileNumberController,
      label: 'File number',
      minLength: 5,
      maxLength: 8,
      buttonLabel: _busy ? 'Finding patient…' : 'Find patient',
      hasError: _error != null,
      busy: _busy,
      scale: scale,
      onSubmit: _findPatient,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppSpacing.twoColBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, SizedBox(height: scale.size(AppSpacing.gapXxl)), Expanded(child: entry)],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Align(alignment: Alignment.topLeft, child: info)),
            SizedBox(width: scale.size(AppSpacing.twoColGap)),
            Expanded(child: entry),
          ],
        );
      },
    );
  }

  /// "Is this the right patient?": patient card + confirm buttons, at the top of the card.
  Widget _buildConfirm(Patient patient, AppScale scale) {
    final gap = scale.size(AppSpacing.gapXxl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Is this the right patient?', 'Check the patient details before selecting supplies.', scale),
        SizedBox(height: gap),
        PatientCard(patient: patient, scale: scale),
        SizedBox(height: gap),
        Wrap(
          spacing: scale.size(AppSpacing.gapM),
          runSpacing: scale.size(AppSpacing.gapM),
          children: [
            AppButton(
              label: 'Yes, select supplies',
              onPressed: _showSuppliesNotReady,
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
            AppButton(
              label: 'No, enter again',
              variant: AppButtonVariant.secondary,
              onPressed: _enterAgain,
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
          ],
        ),
      ],
    );
  }
}
