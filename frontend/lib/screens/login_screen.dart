import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../services/scan_source.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/dashed_border.dart';
import '../widgets/digit_entry.dart';
import '../widgets/id_card_art.dart';
import '../widgets/top_bar.dart';

enum _LoginTab { scan, enterId }

/// Nurse "Identify yourself" screen (prototype: AuthPanel in App.tsx).
/// Two tabs: scan a card, or type the employee ID on the keypad.
/// Both call ApiService.login; the screen never talks HTTP directly.
class LoginScreen extends StatefulWidget {
  /// Where scanned IDs come from. Defaults to a keyboard-style card reader.
  /// A camera scanner can be passed here later without changing this screen.
  final ScanSource? scanSource;

  const LoginScreen({super.key, this.scanSource});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _noStaffIdMessage = 'No staff ID found. Check the number and try again.';
  static const _unreadCardMessage = 'The card could not be read. Scan again or enter your ID.';
  static const _connectionMessage = 'Could not reach the server. Try again.';

  late final ScanSource _scanSource = widget.scanSource ?? KeyboardScanSource();
  StreamSubscription<String>? _scanSub;
  final _idController = TextEditingController();

  _LoginTab _tab = _LoginTab.scan;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanSub = _scanSource.scans.listen((id) => _login(id, LoginMethod.scan));
    _scanSource.start(); // the Scan tab is shown first
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanSource.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _selectTab(_LoginTab tab) {
    setState(() {
      _tab = tab;
      _error = null;
    });
    // Only listen to the card reader while the Scan tab is visible,
    // so typing on the Enter ID tab is never taken as a scan.
    tab == _LoginTab.scan ? _scanSource.start() : _scanSource.stop();
  }

  Future<void> _login(String employeeId, LoginMethod method) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await context.read<ApiService>().login(employeeId, method);
      if (!mounted) return;
      context.read<AuthState>().signIn(response);
      context.go('/signed-in');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.statusCode == 401
          ? _noStaffIdMessage
          : (method == LoginMethod.scan ? _unreadCardMessage : _connectionMessage));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = method == LoginMethod.scan ? _unreadCardMessage : _connectionMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAdminNotReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Supervisor sign in comes in a later step.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    return Scaffold(
      body: Column(
        children: [
          TopBar(onAdmin: _showAdminNotReady),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Short window (e.g. 1280x720, 1280x800): use smaller paddings and keypad
                // so everything fits without scrolling. The scroll view stays as a safety net.
                final short = constraints.maxHeight < AppSpacing.compactHeightBreakpoint;
                final pagePaddingY = short ? AppSpacing.pagePaddingYShort : AppSpacing.pagePaddingY;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: narrow ? AppSpacing.mobileGutter : AppSpacing.pagePaddingX,
                    vertical: pagePaddingY,
                  ),
                  child: ConstrainedBox(
                    // Center the card vertically when there is room (.auth-wrap).
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 2 * pagePaddingY),
                    child: Center(child: _buildCard(narrow: narrow, short: short)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required bool narrow, required bool short}) {
    final sectionGap = short ? AppSpacing.gapM : AppSpacing.gapXxl;
    return Container(
      constraints: const BoxConstraints(maxWidth: AppSpacing.narrowCardMaxWidth),
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? AppSpacing.gapXxl : AppSpacing.authCardPaddingX,
        vertical: short
            ? AppSpacing.authCardPaddingYShort
            : (narrow ? AppSpacing.gapXxl : AppSpacing.authCardPaddingY),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Identify yourself', style: AppText.h1),
          SizedBox(height: short ? AppSpacing.gapXxs : AppSpacing.gapS),
          Text('Scan your nurse card or enter your ID.', style: AppText.bodyMuted),
          SizedBox(height: sectionGap),
          _buildTabs(short: short),
          SizedBox(height: sectionGap),
          if (_error != null)
            AppAlert(
              message: _error!,
              tone: AlertTone.error,
              margin: short
                  ? const EdgeInsets.only(bottom: AppSpacing.gapM)
                  : const EdgeInsets.symmetric(vertical: AppSpacing.gapL),
            ),
          if (_tab == _LoginTab.scan)
            _buildScanPanel()
          else
            DigitEntry(
              controller: _idController,
              minLength: 4,
              maxLength: 6,
              buttonLabel: 'Find my ID',
              hasError: _error != null,
              busy: _busy,
              dense: short,
              onSubmit: () => _login(_idController.text, LoginMethod.manual),
            ),
        ],
      ),
    );
  }

  /// "Scan card | Enter ID" tabs (.tabs): active tab has teal text and a 3 px teal underline.
  Widget _buildTabs({required bool short}) {
    Widget tab(String label, _LoginTab value) {
      final active = _tab == value;
      return Expanded(
        child: InkWell(
          onTap: _busy ? null : () => _selectTab(value),
          child: Container(
            height: short ? AppSpacing.tabHeightShort : AppSpacing.tabHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 3),
              ),
            ),
            child: Text(
              label,
              style: AppText.button.copyWith(color: active ? AppColors.primary : AppColors.muted),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [tab('Scan card', _LoginTab.scan), tab('Enter ID', _LoginTab.enterId)]),
    );
  }

  /// Light-teal panel with a dashed border (.scan-panel).
  Widget _buildScanPanel() {
    return DashedBorder(
      color: AppColors.primary,
      radius: AppSpacing.radiusCard,
      child: Container(
        constraints: const BoxConstraints(minHeight: 385),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IdCardArt(reading: _busy),
            const SizedBox(height: AppSpacing.gapXl),
            Text(
              _busy ? 'Reading card…' : 'Hold your card against the reader below the screen',
              textAlign: TextAlign.center,
              style: AppText.strong,
            ),
            if (AppConfig.demoMode) ...[
              const SizedBox(height: AppSpacing.gapXl),
              AppButton(
                label: _busy ? 'Reading card…' : 'Simulate card scan',
                onPressed: _busy ? null : () => _login(AppConfig.demoNurseId, LoginMethod.scan),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.gapXl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.gapM,
                runSpacing: AppSpacing.gapM,
                children: [
                  // A real reader just needs another tap, so "Scan again" clears the error.
                  AppButton(
                    label: 'Scan again',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => setState(() => _error = null),
                  ),
                  AppButton(
                    label: 'Enter ID',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => _selectTab(_LoginTab.enterId),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
