import 'product_cost.dart';

class Product {
  const Product({
    required this.sku,
    required this.description,
    required this.imageUrl,
    required this.stock,
    required this.brand,
    required this.costHistory,
    this.expirationDate,
  });

  final String sku;
  final String description;
  final String imageUrl;
  final int stock;
  final String brand;
  final List<ProductCost> costHistory;
  final DateTime? expirationDate;

  Product copyWith({
    String? sku,
    String? description,
    String? imageUrl,
    int? stock,
    String? brand,
    List<ProductCost>? costHistory,
    DateTime? expirationDate,
  }) {
    return Product(
      sku: sku ?? this.sku,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      brand: brand ?? this.brand,
      costHistory: costHistory ?? this.costHistory,
      expirationDate: expirationDate ?? this.expirationDate,
    );
  }
}
