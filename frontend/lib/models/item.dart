/// One entry of GET /items (docs/api.md).
class Item {
  final int id;
  final String name;
  final String sku;
  final String category;
  final int slotNumber;
  final int quantity;
  final int minQuantity;
  final bool lowStock; // quantity <= min_quantity

  const Item({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.slotNumber,
    required this.quantity,
    required this.minQuantity,
    required this.lowStock,
  });

  bool get outOfStock => quantity == 0;

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as int,
        name: json['name'] as String,
        sku: json['sku'] as String,
        category: json['category'] as String,
        slotNumber: json['slot_number'] as int,
        quantity: json['quantity'] as int,
        minQuantity: json['min_quantity'] as int,
        lowStock: json['low_stock'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'category': category,
        'slot_number': slotNumber,
        'quantity': quantity,
        'min_quantity': minQuantity,
        'low_stock': lowStock,
      };
}
