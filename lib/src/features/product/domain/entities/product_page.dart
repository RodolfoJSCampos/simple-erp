import 'product.dart';

class ProductPage {
  const ProductPage({required this.items, this.nextCursor});

  final List<Product> items;
  final String? nextCursor;
}
