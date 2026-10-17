import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/scaled_page.dart';
import '../widgets/top_bar.dart';

/// "Supervisor sign in": employee ID + password (Decision 1), opened by "Admin sign in".
/// Minimal for now: it leads to the supervisor dashboard (/supervisor).
/// Only supervisors may sign in here; a nurse ID is refused and the nurse uses the card login.
class SupervisorLoginScreen extends StatefulWidget {
  const SupervisorLoginScreen({super.key});

  @override
  State<SupervisorLoginScreen> createState() => _SupervisorLoginScreenState();
}

class _SupervisorLoginScreenState extends State<SupervisorLoginScreen> {
  // One message for an unknown ID and a wrong password, so the screen never tells
  // someone which of the two was right.
  static const _badLoginMessage = 'Wrong employee ID or password.';
  static const _notSupervisorMessage = 'This sign in is for supervisors. Nurses sign in with their card.';
  static const _connectionMessage = 'Could not reach the server. Try again.';

  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Redraw so "Sign in" turns on once both fields are filled.
    _idController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_busy && _idController.text.isNotEmpty && _passwordController.text.isNotEmpty;

  Future<void> _signIn() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final response = await api.login(_idController.text, LoginMethod.manual, password: _passwordController.text);
      if (!mounted) return;
      if (!response.user.isSupervisor) {
        api.signOut();
        setState(() => _error = _notSupervisorMessage);
        return;
      }
      context.read<AuthState>().signIn(response);
      context.go('/supervisor');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.statusCode == 401 ? _badLoginMessage : _connectionMessage);
    } catch (_) {
      if (mounted) setState(() => _error = _connectionMessage);
    } finally {
      if (mounted) {
        _passwordController.clear(); // never keep a password on screen after a try
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaledPage(
      topBar: const TopBar(),
      cardMaxWidth: AppSpacing.narrowCardMaxWidth,
      cardPaddingX: AppSpacing.authCardPaddingX,
      cardPaddingY: AppSpacing.authCardPaddingY,
      builder: (context, scale) => _buildContent(scale),
    );
  }

  Widget _buildContent(AppScale scale) {
    Widget field(String label, Widget input) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: scale.label),
            SizedBox(height: scale.size(AppSpacing.gapXs)),
            input,
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Supervisor sign in', style: scale.h1),
        SizedBox(height: scale.size(AppSpacing.gapS)),
        Text('Enter your employee ID and password.', style: scale.bodyMuted),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        field(
          'Employee ID',
          TextField(
            key: const Key('supervisor-id'),
            controller: _idController,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            style: scale.body,
            textInputAction: TextInputAction.next,
          ),
        ),
        SizedBox(height: scale.size(AppSpacing.gapL)),
        field(
          'Password',
          TextField(
            key: const Key('supervisor-password'),
            controller: _passwordController,
            enabled: !_busy,
            obscureText: true,
            style: scale.body,
            onSubmitted: (_) => _signIn(),
          ),
        ),
        if (_error != null)
          AppAlert(
            message: _error!,
            tone: AlertTone.error,
            scale: scale,
            margin: EdgeInsets.only(top: scale.size(AppSpacing.gapL)),
          ),
        SizedBox(height: scale.size(AppSpacing.gapXxl)),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: 'Back',
              variant: AppButtonVariant.ghost,
              onPressed: _busy ? null : () => context.go('/login'),
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
            SizedBox(width: scale.size(AppSpacing.gapM)),
            AppButton(
              label: _busy ? 'Signing in…' : 'Sign in',
              onPressed: _canSubmit ? _signIn : null,
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
          ],
        ),
      ],
    );
  }
}
