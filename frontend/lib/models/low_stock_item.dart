import 'item.dart';

/// One entry of GET /reports/low-stock (docs/api.md): the item object plus
/// `qty_to_minimum` (how many units bring it back to its minimum).
class LowStockItem {
  final Item item;
  final int qtyToMinimum;

  const LowStockItem({required this.item, required this.qtyToMinimum});

  factory LowStockItem.fromJson(Map<String, dynamic> json) => LowStockItem(
        item: Item.fromJson(json),
        qtyToMinimum: json['qty_to_minimum'] as int,
      );

  Map<String, dynamic> toJson() => {...item.toJson(), 'qty_to_minimum': qtyToMinimum};
}
