import '../../domain/entities/product_cost.dart';

class ProductCostModel extends ProductCost {
  const ProductCostModel({
    required super.orderId,
    required super.value,
    required super.registeredAt,
    required super.origin,
  });

  factory ProductCostModel.fromEntity(ProductCost entity) {
    return ProductCostModel(
      orderId: entity.orderId,
      value: entity.value,
      registeredAt: entity.registeredAt,
      origin: entity.origin,
    );
  }

  factory ProductCostModel.fromMap(Map<String, dynamic> map) {
    return ProductCostModel(
      orderId: map['orderId'] as String,
      value: (map['value'] as num).toDouble(),
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      origin: map['origin'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'value': value,
      'registeredAt': registeredAt.toIso8601String(),
      'origin': origin,
    };
  }
}
