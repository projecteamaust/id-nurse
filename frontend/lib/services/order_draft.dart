import 'package:flutter/foundation.dart';

import '../models/item.dart';
import '../models/patient.dart';

/// One line of the request being built: an item and how many units.
class DraftLine {
  final Item item;
  final int qty;

  const DraftLine({required this.item, required this.qty});
}

/// The supply request the nurse is building, before it is sent as POST /orders.
/// Patient (step 2) and Supplies (step 3) fill it; Review (step 4) will send it.
/// Kept in memory only, and cleared on sign out.
class OrderDraft extends ChangeNotifier {
  Patient? _patient;
  final List<DraftLine> _lines = [];

  Patient? get patient => _patient;
  List<DraftLine> get lines => List.unmodifiable(_lines);
  int get totalUnits => _lines.fold(0, (sum, line) => sum + line.qty);
  bool get isEmpty => _lines.isEmpty;

  /// Starts a request for [patient]. Choosing another patient empties the item list.
  void start(Patient patient) {
    if (_patient?.fileNumber != patient.fileNumber) _lines.clear();
    _patient = patient;
    notifyListeners();
  }

  /// Units of this item already in the request (0 if none).
  int qtyFor(int itemId) => _lines.where((l) => l.item.id == itemId).firstOrNull?.qty ?? 0;

  /// Adds [qty] units; if the item is already in the request, its quantity grows.
  void add(Item item, int qty) {
    if (qty <= 0) return;
    final index = _lines.indexWhere((l) => l.item.id == item.id);
    if (index == -1) {
      _lines.add(DraftLine(item: item, qty: qty));
    } else {
      _lines[index] = DraftLine(item: item, qty: _lines[index].qty + qty);
    }
    notifyListeners();
  }

  void remove(int itemId) {
    _lines.removeWhere((l) => l.item.id == itemId);
    notifyListeners();
  }

  void clear() {
    _patient = null;
    _lines.clear();
    notifyListeners();
  }
}
