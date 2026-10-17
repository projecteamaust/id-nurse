import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Patient summary box (.patient-card): initials, name, file number and age, room, diagnosis code.
/// Used on the Patient screen now and on the Review screen later.
class PatientCard extends StatelessWidget {
  final Patient patient;

  const PatientCard({super.key, required this.patient});

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
      width: AppSpacing.avatarSize,
      height: AppSpacing.avatarSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
      child: Text(_initials, style: AppText.strong.copyWith(color: AppColors.primary)),
    );
    final name = _Field(
      label: 'Patient',
      value: patient.name,
      detail: 'File ${patient.fileNumber} · Age ${patient.age}',
    );
    final room = _Field(label: 'Room', value: patient.room);
    final diagnosis = _Field(label: 'Diagnosis code', value: patient.diagnosisCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.patientCardPadding),
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
                const SizedBox(width: AppSpacing.patientCardGap),
                Expanded(flex: 14, child: name),
                const SizedBox(width: AppSpacing.patientCardGap),
                Expanded(flex: 7, child: room),
                const SizedBox(width: AppSpacing.patientCardGap),
                Expanded(flex: 10, child: diagnosis),
              ],
            );
          }
          // Narrow (tablet portrait): name on top, room and diagnosis below.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [avatar, const SizedBox(width: AppSpacing.gapL), Expanded(child: name)]),
              const SizedBox(height: AppSpacing.gapL),
              Row(children: [
                Expanded(child: room),
                const SizedBox(width: AppSpacing.gapL),
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

  const _Field({required this.label, required this.value, this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.small),
        const SizedBox(height: 3),
        Text(value, style: AppText.strong),
        if (detail != null) ...[
          const SizedBox(height: 3),
          Text(detail!, style: AppText.small),
        ],
      ],
    );
  }
}
