import '../../domain/entities/order.dart';
import 'order_item_model.dart';

class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.items,
    required super.origin,
    required super.registeredAt,
    super.originIconUrl,
  });

  factory OrderModel.fromEntity(Order entity) {
    return OrderModel(
      id: entity.id,
      items: entity.items
          .map(OrderItemModel.fromEntity)
          .toList(growable: false),
      origin: entity.origin,
      registeredAt: entity.registeredAt,
      originIconUrl: entity.originIconUrl,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] as String,
      items: (map['items'] as List<dynamic>)
          .map((item) => OrderItemModel.fromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      origin: map['origin'] as String,
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      originIconUrl: map['originIconUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items
          .map((item) => OrderItemModel.fromEntity(item).toMap())
          .toList(growable: false),
      'origin': origin,
      'registeredAt': registeredAt.toIso8601String(),
      if (originIconUrl != null) 'originIconUrl': originIconUrl,
    };
  }
}
