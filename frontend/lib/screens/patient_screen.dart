import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/digit_entry.dart';
import '../widgets/patient_card.dart';
import '../widgets/step_tracker.dart';
import '../widgets/top_bar.dart';

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

  void _signOut() {
    context.read<ApiService>().signOut();
    context.read<AuthState>().signOut(); // the router then sends us to /login
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    if (user == null) return const SizedBox.shrink(); // the router sends us back to /login

    final narrow = MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    return Scaffold(
      body: Column(
        children: [
          TopBar(user: user, onSignOut: _signOut),
          const StepTracker(current: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Short window (e.g. 1280x720): smaller paddings and keypad so it fits without scrolling.
                final short = constraints.maxHeight < AppSpacing.compactHeightBreakpoint;
                final pagePaddingY = short ? AppSpacing.pagePaddingYShort : AppSpacing.pagePaddingY;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? AppSpacing.mobileGutter : AppSpacing.pagePaddingX,
                    vertical: pagePaddingY,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildCard(narrow: narrow, short: short),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The white main card (.main-card).
  Widget _buildCard({required bool narrow, required bool short}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: AppSpacing.mainCardMaxWidth),
      padding: EdgeInsets.all(narrow ? AppSpacing.gapXxl : AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: _patient == null ? _buildEntry(short: short) : _buildConfirm(_patient!),
    );
  }

  /// Heading + muted subtitle (.heading-group).
  Widget _heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.h1),
        const SizedBox(height: AppSpacing.gapS),
        Text(subtitle, style: AppText.bodyMuted),
      ],
    );
  }

  /// "Which patient?": text on the left, keypad on the right (.two-col-entry).
  /// Stacks into one column when the card is narrow.
  Widget _buildEntry({required bool short}) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Which patient?', 'Enter the patient file number.'),
        const SizedBox(height: AppSpacing.gapS),
        const AppAlert(
          message: 'Patient details are used only for this supply request.',
          tone: AlertTone.success,
        ),
        if (_error != null)
          AppAlert(message: _error!, tone: AlertTone.error, margin: EdgeInsets.zero),
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
      dense: short,
      onSubmit: _findPatient,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppSpacing.twoColBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, const SizedBox(height: AppSpacing.gapXxl), entry],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info),
            const SizedBox(width: AppSpacing.twoColGap),
            Expanded(child: entry),
          ],
        );
      },
    );
  }

  /// "Is this the right patient?": patient card + confirm buttons.
  Widget _buildConfirm(Patient patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Is this the right patient?', 'Check the patient details before selecting supplies.'),
        const SizedBox(height: AppSpacing.gapXxl),
        PatientCard(patient: patient),
        const SizedBox(height: AppSpacing.gapXxl),
        Wrap(
          spacing: AppSpacing.gapM,
          runSpacing: AppSpacing.gapM,
          children: [
            AppButton(label: 'Yes, select supplies', onPressed: _showSuppliesNotReady),
            AppButton(label: 'No, enter again', variant: AppButtonVariant.secondary, onPressed: _enterAgain),
          ],
        ),
      ],
    );
  }
}
