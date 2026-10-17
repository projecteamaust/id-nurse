import 'order.dart';

/// What the Prepare screen shows, worked out only from an order's `qty_dispensed`
/// (docs/api.md: "The frontend calculates progress from qty_dispensed").
/// The robot picks the lines in order, so the current line is the first one not finished.
class OrderProgress {
  /// Lines of the order, in the order the robot picks them.
  final List<OrderItem> lines;

  const OrderProgress._(this.lines);

  factory OrderProgress.from(Order order) => OrderProgress._(order.items);

  int get itemCount => lines.length;

  int get totalUnits => lines.fold(0, (sum, l) => sum + l.qtyRequested);

  int get unitsPicked => lines.fold(0, (sum, l) => sum + l.qtyDispensed);

  int get unitsLeft => totalUnits - unitsPicked;

  /// 0.0 .. 1.0 for a progress bar.
  double get fraction => totalUnits == 0 ? 0 : unitsPicked / totalUnits;

  /// Index of the line being picked now, or null when every line is finished.
  int? get currentIndex {
    final i = lines.indexWhere((l) => l.qtyDispensed < l.qtyRequested);
    return i == -1 ? null : i;
  }

  /// The line being picked now, or null when every line is finished.
  OrderItem? get current => currentIndex == null ? null : lines[currentIndex!];

  /// 1-based number of the current line ("Item 2 of 3"); [itemCount] when all are finished.
  int get currentNumber => (currentIndex ?? itemCount - 1) + 1;

  /// Slots whose line has been picked completely.
  Set<int> get finishedSlots => {
        for (final l in lines)
          if (l.qtyDispensed >= l.qtyRequested) l.slotNumber,
      };
}
