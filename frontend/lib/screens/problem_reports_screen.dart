import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/problem_report.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/admin_shell.dart';
import '../widgets/status_chip.dart';

/// Supervisor dashboard page "Problem reports": open reports from nurses about PARTIAL /
/// FAILED orders, with "Mark resolved". Shown inside [AdminShell]; keeps the sidebar badge
/// ([AdminCounts.openReports]) in step with the list.
/// Loads once when it opens; "Refresh" loads again (no polling).
class ProblemReportsScreen extends StatefulWidget {
  const ProblemReportsScreen({super.key});

  @override
  State<ProblemReportsScreen> createState() => _ProblemReportsScreenState();
}

class _ProblemReportsScreenState extends State<ProblemReportsScreen> {
  List<ProblemReport>? _reports;
  bool _loading = false;
  String? _error;
  final Set<int> _resolving = {}; // reports whose "Mark resolved" is in flight

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await context.read<ApiService>().listProblemReports();
      if (!mounted) return;
      setState(() => _reports = reports);
      context.read<AdminCounts>().openReports = reports.length;
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the problem reports. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(ProblemReport report) async {
    setState(() {
      _resolving.add(report.id);
      _error = null;
    });
    try {
      await context.read<ApiService>().resolveProblemReport(report.id);
      if (mounted) _removeReport(report);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        _removeReport(report); // someone else already resolved it: it is no longer open
      } else {
        setState(() => _error = 'Could not mark report for order #${report.orderId} as resolved. Try again.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not mark report for order #${report.orderId} as resolved. Try again.');
    } finally {
      if (mounted) setState(() => _resolving.remove(report.id));
    }
  }

  void _removeReport(ProblemReport report) {
    setState(() => _reports?.removeWhere((r) => r.id == report.id));
    context.read<AdminCounts>().openReports = _reports?.length;
  }

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AppScale>();
    final reports = _reports;
    return AdminCard(child: _buildContent(reports, scale));
  }

  Widget _buildContent(List<ProblemReport>? reports, AppScale scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .section-head: what this list is, the open count and "Refresh".
        Row(
          children: [
            Expanded(
              child: Text('Reports from nurses about orders that were not fully dispensed.', style: scale.bodyMuted),
            ),
            if (reports != null) ...[
              StatusChip(
                label: '${reports.length} open',
                tone: reports.isEmpty ? ChipTone.success : ChipTone.warning,
                scale: scale,
              ),
              SizedBox(width: scale.size(AppSpacing.gapM)),
            ],
            AppButton(
              label: 'Refresh',
              variant: AppButtonVariant.secondary,
              onPressed: _loading ? null : _load,
              height: scale.buttonHeight,
              textStyle: scale.button,
            ),
          ],
        ),
        SizedBox(height: scale.size(AppSpacing.gapXl)),
        if (_error != null)
          AppAlert(
            message: _error!,
            tone: AlertTone.error,
            scale: scale,
            margin: EdgeInsets.only(bottom: scale.size(AppSpacing.gapL)),
          ),
        Expanded(child: _buildList(reports, scale)),
      ],
    );
  }

  Widget _buildList(List<ProblemReport>? reports, AppScale scale) {
    if (reports == null) {
      return _loading ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
    }
    if (reports.isEmpty) {
      return Center(child: Text('No open problem reports', style: scale.bodyMuted));
    }
    // Bordered alert list; sized to its rows, and scrolls inside its own box if there are many.
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard - 1),
          child: ListView.separated(
            key: const Key('report-list'),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: reports.length,
            separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.border),
            itemBuilder: (context, i) => _buildRow(reports[i], scale),
          ),
        ),
      ),
    );
  }

  /// One report: warning dot, "Order #17 · Maya Chen · time", what is missing, the note,
  /// and "Mark resolved".
  Widget _buildRow(ProblemReport report, AppScale scale) {
    final when = DateFormat.MMMd().add_jm().format(DateTime.parse(report.createdAt).toLocal());
    final missing = report.missingItems.map((m) => '${m.name} ×${m.qtyMissing}').join(', ');
    final small = scale.text(AppText.small.copyWith(fontSize: 14));
    final busy = _resolving.contains(report.id);
    return Padding(
      key: ValueKey('report-${report.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: scale.size(AppSpacing.reviewLinePaddingX),
        vertical: scale.size(AppSpacing.reviewLinePaddingY),
      ),
      child: Row(
        children: [
          Container(
            width: scale.size(AppSpacing.stepDotSize),
            height: scale.size(AppSpacing.stepDotSize),
            decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
          ),
          SizedBox(width: scale.size(AppSpacing.gapL)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${report.orderId} · ${report.nurse.name} · $when',
                  style: scale.strong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  missing.isEmpty ? 'Not dispensed: nothing listed' : 'Not dispensed: $missing',
                  style: small.copyWith(color: AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (report.note != null)
                  Text(
                    '“${report.note}”',
                    style: small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(width: scale.size(AppSpacing.gapL)),
          AppButton(
            label: busy ? 'Resolving…' : 'Mark resolved',
            variant: AppButtonVariant.secondary,
            onPressed: busy ? null : () => _resolve(report),
            height: scale.buttonHeight,
            textStyle: scale.button,
          ),
        ],
      ),
    );
  }
}
