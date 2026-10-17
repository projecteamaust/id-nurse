import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_alert.dart';
import 'app_button.dart';
import 'order_line_row.dart';

/// Warning that names what was not dispensed, with a "Report problem" button under it
/// (used on Collect for PARTIAL and on the FAILED result). After sending, the warning
/// turns green and the button becomes a disabled "Problem reported".
/// [actions] are extra buttons placed after "Report problem" in the same row.
class ProblemReportPanel extends StatefulWidget {
  final Order order;
  final AppScale scale;
  final List<Widget> actions;

  const ProblemReportPanel({super.key, required this.order, required this.scale, this.actions = const []});

  @override
  State<ProblemReportPanel> createState() => _ProblemReportPanelState();
}

class _ProblemReportPanelState extends State<ProblemReportPanel> {
  bool _reported = false;

  Future<void> _openDialog() async {
    final reported = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.modalBackdrop,
      builder: (_) => ReportProblemDialog(order: widget.order, scale: widget.scale),
    );
    if (reported == true && mounted) setState(() => _reported = true);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final missing = notDispensedText(widget.order.items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAlert(
          key: const Key('supervisor-alert'),
          message: _reported
              ? 'Problem reported to your supervisor. Not dispensed: $missing.'
              : 'Not dispensed: $missing. Please report the problem to your supervisor.',
          tone: _reported ? AlertTone.success : AlertTone.warning,
          scale: scale,
          margin: EdgeInsets.zero,
        ),
        SizedBox(height: scale.size(AppSpacing.gapL)),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: scale.size(AppSpacing.gapM),
          runSpacing: scale.size(AppSpacing.gapS),
          children: [
            AppButton(
              label: _reported ? 'Problem reported' : 'Report problem',
              variant: AppButtonVariant.secondary,
              onPressed: _reported ? null : _openDialog,
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
            ...widget.actions,
          ],
        ),
      ],
    );
  }
}

/// "Report a problem" dialog (.modal): what is missing, an optional short note, Cancel / Send.
/// Sends POST /orders/{id}/report. Closes with true when the report is sent, or when the
/// order already has an open report (409): either way the supervisor knows about it.
class ReportProblemDialog extends StatefulWidget {
  final Order order;
  final AppScale scale;

  const ReportProblemDialog({super.key, required this.order, required this.scale});

  @override
  State<ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<ReportProblemDialog> {
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<ApiService>().reportProblem(widget.order.id, note: _note.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409 && e.detail == 'This order already has an open report') {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _sending = false;
        _error = e.detail;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Could not send the report. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.modalMaxWidth),
        child: Padding(
          padding: EdgeInsets.all(scale.size(AppSpacing.modalPadding)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Report a problem', style: scale.text(AppText.h2)),
              SizedBox(height: scale.size(AppSpacing.gapS)),
              Text(
                'Order #${widget.order.id} · Not dispensed: ${notDispensedText(widget.order.items)}',
                style: scale.bodyMuted,
              ),
              SizedBox(height: scale.size(AppSpacing.modalHeadGap)),
              TextField(
                key: const Key('report-note'),
                controller: _note,
                enabled: !_sending,
                maxLength: AppConfig.maxReportNoteLength,
                maxLines: 2,
                style: scale.body,
                decoration: const InputDecoration(hintText: 'What happened? (optional)'),
              ),
              if (_error != null)
                AppAlert(
                  message: _error!,
                  tone: AlertTone.error,
                  scale: scale,
                  margin: EdgeInsets.only(top: scale.size(AppSpacing.gapS)),
                ),
              SizedBox(height: scale.size(AppSpacing.gapL)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.secondary,
                    onPressed: _sending ? null : () => Navigator.of(context).pop(false),
                    height: scale.buttonHeight,
                    textStyle: scale.button,
                  ),
                  SizedBox(width: scale.size(AppSpacing.gapM)),
                  AppButton(
                    label: _sending ? 'Sending…' : 'Send',
                    onPressed: _sending ? null : _send,
                    height: scale.buttonHeight,
                    textStyle: scale.button,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
