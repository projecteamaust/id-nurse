import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/file_saver.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/admin_shell.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/log_filter_bar.dart';

/// Supervisor dashboard page "Reports": exports the dispense report (GET
/// /reports/dispense.csv) as a CSV file, with the same From / To / Nurse filters as the
/// Dispensing log. The file is saved through [FileSaver] (desktop: the Downloads folder).
/// PDF and Excel reports are a later phase.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  LogFilters _filters = const LogFilters();
  bool _exporting = false;

  /// What the last export did: the message and its color.
  (String, AlertTone)? _result;

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _result = null;
    });
    final api = context.read<ApiService>();
    final saver = context.read<FileSaver>();
    try {
      final csv = await api.exportDispenseCsv(from: _filters.from, to: _filters.to, nurseId: _filters.nurseId);
      // Rows after the header row (the CSV ends with a line break).
      final rows = csv.trimRight().split('\n').length - 1;
      if (rows == 0) {
        if (mounted) setState(() => _result = ('No orders match these filters. Nothing was saved.', AlertTone.warning));
        return;
      }
      final fileName = 'dispense-report-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      final path = await saver.save(fileName, csv);
      final savedName = path.split(RegExp(r'[\\/]')).last;
      if (mounted) {
        setState(() => _result = (
              'Saved $savedName to ${saver.folderName} ($rows ${rows == 1 ? 'row' : 'rows'}).',
              AlertTone.success,
            ));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _result = ('Could not export the report: ${e.detail}', AlertTone.error));
    } catch (_) {
      if (mounted) setState(() => _result = ('Could not save the report. Try again.', AlertTone.error));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AppScale>();
    final result = _result;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dispense report (CSV)', style: scale.text(AppText.h2)),
          SizedBox(height: scale.size(AppSpacing.gapS)),
          Text(
            'One row per item line of every order that was not cancelled: order, dates, status, '
            'patient file number, nurse, item, slot, units requested and dispensed. '
            'Use it for insurance claims and audits.',
            style: scale.bodyMuted,
          ),
          SizedBox(height: scale.size(AppSpacing.gapXl)),
          LogFilterBar(
            filters: _filters,
            onChanged: (filters) => setState(() {
              _filters = filters;
              _result = null; // the old message was about other filters
            }),
            scale: scale,
          ),
          SizedBox(height: scale.size(AppSpacing.gapXl)),
          AppButton(
            key: const Key('export-csv'),
            label: _exporting ? 'Exporting…' : 'Export CSV',
            onPressed: _exporting ? null : _export,
            height: scale.buttonHeight,
            textStyle: scale.button,
          ),
          if (result != null)
            AppAlert(
              key: const Key('export-result'),
              message: result.$1,
              tone: result.$2,
              scale: scale,
              margin: EdgeInsets.only(top: scale.size(AppSpacing.gapXl)),
            ),
        ],
      ),
    );
  }
}
