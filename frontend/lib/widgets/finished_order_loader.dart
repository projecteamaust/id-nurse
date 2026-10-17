import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../theme/app_scale.dart';
import '../theme/app_spacing.dart';
import 'app_alert.dart';
import 'app_button.dart';

/// Loads a finished order once with GET /orders/{id} for the Collect and Complete steps.
/// These steps only exist after DONE or PARTIAL (Decision 6), so any other status goes
/// back to the Prepare screen, which knows how to show every state.
/// While loading it shows a spinner; if loading fails, a message and "Try again".
class FinishedOrderLoader extends StatefulWidget {
  final int orderId;
  final AppScale scale;
  final Widget Function(Order order) builder;

  const FinishedOrderLoader({super.key, required this.orderId, required this.scale, required this.builder});

  @override
  State<FinishedOrderLoader> createState() => _FinishedOrderLoaderState();
}

class _FinishedOrderLoaderState extends State<FinishedOrderLoader> {
  Order? _order;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final order = await context.read<ApiService>().getOrder(widget.orderId);
      if (!mounted) return;
      if (order.status != OrderStatus.done && order.status != OrderStatus.partial) {
        context.go('/prepare/${order.id}');
        return;
      }
      setState(() => _order = order);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order != null) return widget.builder(order);
    if (!_failed) return const Center(child: CircularProgressIndicator());
    final scale = widget.scale;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAlert(message: 'Could not load the order. Please try again.', tone: AlertTone.error, scale: scale),
          SizedBox(height: scale.size(AppSpacing.gapS)),
          AppButton(label: 'Try again', onPressed: _load, height: scale.buttonHeight, textStyle: scale.button),
        ],
      ),
    );
  }
}
