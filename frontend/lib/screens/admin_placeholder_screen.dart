import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_scale.dart';
import '../widgets/admin_shell.dart';

/// TEMPORARY page for the dashboard pages that are built in the next tasks
/// (Low stock, Dispensing log, Reports). Each task replaces one of these.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AppScale>();
    return AdminCard(
      child: Center(child: Text('This page is added in the next step.', style: scale.bodyMuted)),
    );
  }
}
