import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// The filters of GET /orders, GET /audit and GET /reports/dispense.csv:
/// From / To day (inclusive, both optional) and one nurse (user id).
class LogFilters {
  final DateTime? from;
  final DateTime? to;
  final int? nurseId;

  const LogFilters({this.from, this.to, this.nurseId});

  bool get isEmpty => from == null && to == null && nurseId == null;
}

/// Filter row (.toolbar) for the Dispensing log and Reports: "From: …" and "To: …"
/// (Flutter's date picker), a Nurse dropdown (GET /users?role=nurse) and "Clear filters".
/// From can not be after To, and To not before From. [leading] and [trailing] go in the
/// same row (it wraps onto a second line on narrow windows).
class LogFilterBar extends StatefulWidget {
  final LogFilters filters;
  final ValueChanged<LogFilters> onChanged;
  final AppScale scale;
  final List<Widget> leading;
  final List<Widget> trailing;

  const LogFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.scale,
    this.leading = const [],
    this.trailing = const [],
  });

  @override
  State<LogFilterBar> createState() => _LogFilterBarState();
}

class _LogFilterBarState extends State<LogFilterBar> {
  static final _dayFormat = DateFormat.yMMMd();

  List<User> _nurses = const [];

  @override
  void initState() {
    super.initState();
    _loadNurses();
  }

  Future<void> _loadNurses() async {
    try {
      final nurses = await context.read<ApiService>().listUsers(role: 'nurse');
      if (mounted) setState(() => _nurses = nurses);
    } catch (_) {
      // Without the list the nurse filter just offers "All nurses".
    }
  }

  Future<void> _pickDay({required bool from}) async {
    final f = widget.filters;
    final today = DateUtils.dateOnly(DateTime.now());
    final first = from ? DateTime(2020) : (f.from ?? DateTime(2020));
    final last = from ? (f.to ?? today) : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? f.from : f.to) ?? (last.isBefore(today) ? last : today),
      firstDate: first,
      lastDate: last,
      helpText: from ? 'Show from' : 'Show until',
    );
    if (picked == null || !mounted) return;
    widget.onChanged(from
        ? LogFilters(from: picked, to: f.to, nurseId: f.nurseId)
        : LogFilters(from: f.from, to: picked, nurseId: f.nurseId));
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final f = widget.filters;
    final gap = scale.size(AppSpacing.toolbarGap);
    final buttonText = scale.text(AppText.button.copyWith(fontSize: 15));
    String day(DateTime? d) => d == null ? 'any day' : _dayFormat.format(d);

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...widget.leading,
        AppButton(
          key: const Key('filter-from'),
          label: 'From: ${day(f.from)}',
          variant: AppButtonVariant.secondary,
          onPressed: () => _pickDay(from: true),
          height: scale.buttonHeight,
          textStyle: buttonText,
        ),
        AppButton(
          key: const Key('filter-to'),
          label: 'To: ${day(f.to)}',
          variant: AppButtonVariant.secondary,
          onPressed: () => _pickDay(from: false),
          height: scale.buttonHeight,
          textStyle: buttonText,
        ),
        _buildNurseFilter(scale),
        AppButton(
          label: 'Clear filters',
          variant: AppButtonVariant.ghost,
          onPressed: f.isEmpty ? null : () => widget.onChanged(const LogFilters()),
          height: scale.buttonHeight,
          textStyle: buttonText,
        ),
        ...widget.trailing,
      ],
    );
  }

  /// "All nurses" or one nurse, in a field that looks like the secondary buttons.
  Widget _buildNurseFilter(AppScale scale) {
    final f = widget.filters;
    final style = scale.text(AppText.button.copyWith(fontSize: 15, color: AppColors.text));
    return Container(
      width: AppSpacing.nurseFilterWidth * scale.textFactor,
      height: scale.buttonHeight,
      padding: EdgeInsets.symmetric(horizontal: scale.size(AppSpacing.gapL)),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          key: const Key('filter-nurse'),
          value: f.nurseId,
          isExpanded: true,
          style: style,
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text('All nurses', style: style)),
            for (final n in _nurses) DropdownMenuItem<int?>(value: n.id, child: Text(n.name, style: style)),
          ],
          onChanged: (id) => widget.onChanged(LogFilters(from: f.from, to: f.to, nurseId: id)),
        ),
      ),
    );
  }
}
