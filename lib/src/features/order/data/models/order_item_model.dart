import '../../domain/entities/order_item.dart';

class OrderItemModel extends OrderItem {
  const OrderItemModel({
    required super.productSku,
    required super.quantity,
    required super.costPerItem,
    required super.expirationDate,
  });

  factory OrderItemModel.fromEntity(OrderItem entity) {
    return OrderItemModel(
      productSku: entity.productSku,
      quantity: entity.quantity,
      costPerItem: entity.costPerItem,
      expirationDate: entity.expirationDate,
    );
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productSku: map['productSku'] as String,
      quantity: map['quantity'] as int,
      costPerItem: (map['costPerItem'] as num).toDouble(),
      expirationDate: DateTime.parse(map['expirationDate'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productSku': productSku,
      'quantity': quantity,
      'costPerItem': costPerItem,
      'expirationDate': expirationDate.toIso8601String(),
    };
  }
}
