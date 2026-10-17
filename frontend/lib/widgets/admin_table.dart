import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// One column of an [AdminTable]: header text, share of the width and alignment.
class AdminColumn {
  final String label;
  final int flex;
  final bool alignEnd; // numbers and buttons line up on the right

  const AdminColumn(this.label, {this.flex = 1, this.alignEnd = false});
}

/// Supervisor dashboard table (.table-wrap / table / th / td): a fixed header row on a
/// light grey background, then the rows. Sized to its rows; when there are more rows
/// than fit, only the rows scroll, inside the table's own box (never the page).
class AdminTable extends StatelessWidget {
  final List<AdminColumn> columns;

  /// One list of cells per row, in [columns] order.
  final List<List<Widget>> rows;
  final AppScale scale;

  /// Key of the scrolling body, for tests.
  final Key? bodyKey;

  const AdminTable({super.key, required this.columns, required this.rows, required this.scale, this.bodyKey});

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(
      horizontal: scale.size(AppSpacing.tableCellPaddingX),
      vertical: scale.size(AppSpacing.tableCellPaddingY),
    );
    final headerStyle = scale.text(AppText.tableHeader.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.03 * 13));

    Widget line(List<Widget> cells, {Color? color}) => Container(
          color: color,
          padding: padding,
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(
                  flex: columns[i].flex,
                  child: Align(
                    alignment: columns[i].alignEnd ? Alignment.centerRight : Alignment.centerLeft,
                    child: cells[i],
                  ),
                ),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton - 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line(
              [for (final c in columns) Text(c.label.toUpperCase(), style: headerStyle, maxLines: 1)],
              color: AppColors.tableHeader,
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Flexible(
              child: ListView.separated(
                key: bodyKey,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: AppColors.border),
                itemBuilder: (context, i) => line(rows[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
