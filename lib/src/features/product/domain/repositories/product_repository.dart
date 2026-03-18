import '../entities/product.dart';
import '../entities/product_cost.dart';
import '../entities/product_page.dart';

abstract interface class ProductRepository {
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(String sku);
  Future<Product?> findBySku(String sku);
  Future<List<Product>> listProducts();
  Future<ProductPage> listProductsPage({required int limit, String? afterSku});
  Future<void> updateStock(String sku, int newStock);
  Future<void> updateExpirationDate(String sku, DateTime newExpirationDate);
  Future<List<String>> listBrands();
  Future<void> addBrand(String brand);
  Future<void> addCostToProduct(String sku, ProductCost cost);
}
