import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../services/scan_source.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/dashed_border.dart';
import '../widgets/digit_entry.dart';
import '../widgets/id_card_art.dart';
import '../widgets/scaled_page.dart';
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
      context.go('/patient');
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

  /// Login stacks heading, tabs, error and keypad in one column, more than the nurse
  /// screens, so its spacing shrinks sooner: it is the prototype size only at about
  /// 1130 px window height (1000 + 80 + 48) and 0.6x at 1280x720, which is what is needed
  /// there to fit the Enter ID tab with an error. Text size is not affected (see AppScale).
  static const _spacingReferenceHeight = 1000.0;

  /// Below a 1280x720 window (720 - 80) the page scrolls instead of squeezing.
  static const _minFitHeight = 640.0;

  @override
  Widget build(BuildContext context) {
    return ScaledPage(
      topBar: TopBar(onAdmin: () => context.go('/supervisor/login')),
      cardMaxWidth: AppSpacing.narrowCardMaxWidth,
      cardPaddingX: AppSpacing.authCardPaddingX,
      cardPaddingY: AppSpacing.authCardPaddingY,
      spacingReferenceHeight: _spacingReferenceHeight,
      minFitHeight: _minFitHeight,
      builder: (context, scale) => _buildContent(scale),
    );
  }

  /// Heading, tabs, then the active tab's panel filling the rest of the card (.auth-card).
  Widget _buildContent(AppScale scale) {
    final sectionGap = scale.size(AppSpacing.gapXxl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Identify yourself', style: scale.h1),
        SizedBox(height: scale.size(AppSpacing.gapS)),
        Text('Scan your nurse card or enter your ID.', style: scale.bodyMuted),
        SizedBox(height: sectionGap),
        _buildTabs(scale),
        SizedBox(height: sectionGap),
        if (_error != null)
          AppAlert(
            message: _error!,
            tone: AlertTone.error,
            scale: scale,
            margin: EdgeInsets.only(bottom: scale.size(AppSpacing.gapM)),
          ),
        Expanded(
          child: _tab == _LoginTab.scan
              ? _buildScanPanel(scale)
              : DigitEntry(
                  controller: _idController,
                  minLength: 4,
                  maxLength: 6,
                  buttonLabel: 'Find my ID',
                  hasError: _error != null,
                  busy: _busy,
                  scale: scale,
                  onSubmit: () => _login(_idController.text, LoginMethod.manual),
                ),
        ),
      ],
    );
  }

  /// "Scan card | Enter ID" tabs (.tabs): active tab has teal text and a 3 px teal underline.
  Widget _buildTabs(AppScale scale) {
    Widget tab(String label, _LoginTab value) {
      final active = _tab == value;
      return Expanded(
        child: InkWell(
          onTap: _busy ? null : () => _selectTab(value),
          child: Container(
            height: scale.control(AppSpacing.tabHeight),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 3),
              ),
            ),
            child: Text(
              label,
              style: scale.button.copyWith(color: active ? AppColors.primary : AppColors.muted),
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

  /// Light-teal panel with a dashed border (.scan-panel), filling the space it is given.
  Widget _buildScanPanel(AppScale scale) {
    final gap = scale.size(AppSpacing.gapXl);
    Widget button(String label, VoidCallback? onPressed, {AppButtonVariant variant = AppButtonVariant.primary}) =>
        AppButton(
          label: label,
          onPressed: onPressed,
          variant: variant,
          height: scale.buttonHeight,
          textStyle: scale.button,
        );

    return DashedBorder(
      color: AppColors.primary,
      radius: AppSpacing.radiusCard,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(scale.size(AppSpacing.scanPanelPadding)),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IdCardArt(reading: _busy, scale: scale),
            SizedBox(height: gap),
            Text(
              _busy ? 'Reading card…' : 'Hold your card against the reader below the screen',
              textAlign: TextAlign.center,
              style: scale.strong,
            ),
            if (AppConfig.demoMode) ...[
              SizedBox(height: gap),
              button(
                _busy ? 'Reading card…' : 'Simulate card scan',
                _busy ? null : () => _login(AppConfig.demoNurseId, LoginMethod.scan),
              ),
            ],
            if (_error != null) ...[
              SizedBox(height: gap),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: scale.size(AppSpacing.gapM),
                runSpacing: scale.size(AppSpacing.gapM),
                children: [
                  // A real reader just needs another tap, so "Scan again" clears the error.
                  button('Scan again', () => setState(() => _error = null), variant: AppButtonVariant.secondary),
                  button('Enter ID', () => _selectTab(_LoginTab.enterId), variant: AppButtonVariant.ghost),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
