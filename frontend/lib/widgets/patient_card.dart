import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';

/// Patient summary box (.patient-card): initials, name, file number and age, room, diagnosis code.
/// Used on the Patient screen now and on the Review screen later.
class PatientCard extends StatelessWidget {
  final Patient patient;
  final AppScale scale;

  const PatientCard({super.key, required this.patient, this.scale = AppScale.none});

  /// "Alex Morgan" -> "AM"
  String get _initials => patient.name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: scale.size(AppSpacing.avatarSize),
      height: scale.size(AppSpacing.avatarSize),
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
      child: Text(_initials, style: scale.strong.copyWith(color: AppColors.primary)),
    );
    final name = _Field(
      label: 'Patient',
      value: patient.name,
      detail: 'File ${patient.fileNumber} · Age ${patient.age}',
      scale: scale,
    );
    final room = _Field(label: 'Room', value: patient.room, scale: scale);
    final diagnosis = _Field(label: 'Diagnosis code', value: patient.diagnosisCode, scale: scale);
    final gap = scale.size(AppSpacing.patientCardGap);
    final narrowGap = scale.size(AppSpacing.gapL);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(scale.size(AppSpacing.patientCardPadding)),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Wide: one row with columns 1.4 : 0.7 : 1 like the prototype grid.
          if (constraints.maxWidth >= AppSpacing.patientCardBreakpoint) {
            return Row(
              children: [
                avatar,
                SizedBox(width: gap),
                Expanded(flex: 14, child: name),
                SizedBox(width: gap),
                Expanded(flex: 7, child: room),
                SizedBox(width: gap),
                Expanded(flex: 10, child: diagnosis),
              ],
            );
          }
          // Narrow (tablet portrait): name on top, room and diagnosis below.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [avatar, SizedBox(width: narrowGap), Expanded(child: name)]),
              SizedBox(height: narrowGap),
              Row(children: [
                Expanded(child: room),
                SizedBox(width: narrowGap),
                Expanded(child: diagnosis),
              ]),
            ],
          );
        },
      ),
    );
  }
}

/// Small muted label, bold value, optional muted detail line.
class _Field extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final AppScale scale;

  const _Field({required this.label, required this.value, this.detail, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: scale.small),
        SizedBox(height: scale.size(3)),
        Text(value, style: scale.strong),
        if (detail != null) ...[
          SizedBox(height: scale.size(3)),
          Text(detail!, style: scale.small),
        ],
      ],
    );
  }
}
