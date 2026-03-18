import '../../domain/entities/product.dart';
import 'product_cost_model.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.sku,
    required super.description,
    required super.imageUrl,
    required super.stock,
    required super.brand,
    required super.costHistory,
    super.expirationDate,
  });

  factory ProductModel.fromEntity(Product entity) {
    return ProductModel(
      sku: entity.sku,
      description: entity.description,
      imageUrl: entity.imageUrl,
      stock: entity.stock,
      brand: entity.brand,
      costHistory: entity.costHistory
          .map(ProductCostModel.fromEntity)
          .toList(growable: false),
      expirationDate: entity.expirationDate,
    );
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    final costs = (map['costHistory'] as List<dynamic>)
        .map((item) => ProductCostModel.fromMap(item as Map<String, dynamic>))
        .toList(growable: false);
    final rawExpirationDate = map['expirationDate'];

    return ProductModel(
      sku: map['sku'] as String,
      description: map['description'] as String,
      imageUrl: map['imageUrl'] as String? ?? '',
      stock: map['stock'] as int,
      brand: map['brand'] as String,
      costHistory: costs,
      expirationDate:
          rawExpirationDate is String && rawExpirationDate.isNotEmpty
          ? DateTime.parse(rawExpirationDate)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sku': sku,
      'description': description,
      'imageUrl': imageUrl,
      'stock': stock,
      'brand': brand,
      'costHistory': costHistory
          .map((item) => ProductCostModel.fromEntity(item).toMap())
          .toList(growable: false),
      if (expirationDate != null)
        'expirationDate': expirationDate!.toIso8601String(),
    };
  }
}
