import 'package:flutter_test/flutter_test.dart';
import 'package:id_nurse/models/order.dart';
import 'package:id_nurse/models/order_progress.dart';

/// An order in the GET /orders/{id} shape with lines (item id, slot, requested, dispensed).
Order _order(List<(int, int, int, int)> lines) => Order.fromJson({
      'id': 17,
      'status': 'DISPENSING',
      'patient': {'file_number': '284913', 'name': 'Alex Morgan'},
      'nurse': {'employee_id': '48216', 'name': 'Maya Chen'},
      'created_at': '2026-10-16T08:45:12+03:00',
      'approved_at': '2026-10-16T08:45:20+03:00',
      'completed_at': null,
      'items': [
        for (final (id, slot, requested, dispensed) in lines)
          {'item_id': id, 'name': 'Item $id', 'slot_number': slot, 'qty_requested': requested, 'qty_dispensed': dispensed},
      ],
    });

void main() {
  test('nothing picked yet: item 1 of 3, first slot', () {
    final p = OrderProgress.from(_order([(1, 1, 2, 0), (2, 2, 1, 0), (5, 5, 4, 0)]));
    expect(p.itemCount, 3);
    expect(p.currentNumber, 1);
    expect(p.current!.slotNumber, 1);
    expect(p.unitsPicked, 0);
    expect(p.totalUnits, 7);
    expect(p.unitsLeft, 7);
    expect(p.fraction, 0);
    expect(p.finishedSlots, isEmpty);
  });

  test('first line done, second started: item 2 of 3, slot 2', () {
    final p = OrderProgress.from(_order([(1, 1, 2, 2), (2, 2, 3, 1), (5, 5, 4, 0)]));
    expect(p.currentNumber, 2);
    expect(p.current!.slotNumber, 2);
    expect(p.current!.name, 'Item 2');
    expect(p.unitsPicked, 3);
    expect(p.fraction, closeTo(3 / 9, 1e-9));
    expect(p.finishedSlots, {1});
  });

  test('everything picked: no current line, all slots finished', () {
    final p = OrderProgress.from(_order([(1, 1, 2, 2), (2, 2, 1, 1)]));
    expect(p.current, isNull);
    expect(p.currentNumber, 2); // stays on the last item
    expect(p.unitsLeft, 0);
    expect(p.fraction, 1);
    expect(p.finishedSlots, {1, 2});
  });
}
