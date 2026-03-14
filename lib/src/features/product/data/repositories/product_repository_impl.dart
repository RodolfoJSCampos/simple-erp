import '../../domain/entities/product.dart';
import '../../domain/entities/product_cost.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';
import '../../../shared/data/datasources/in_memory_erp_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._dataSource);

  final InMemoryErpDataSource _dataSource;

  @override
  Future<void> addBrand(String brand) async {
    _dataSource.brands.add(brand.trim());
  }

  @override
  Future<void> addCostToProduct(String sku, ProductCost cost) async {
    final current = _dataSource.products[sku];
    if (current == null) {
      return;
    }

    final model = ProductModel.fromMap(current);
    final updated = model.copyWith(costHistory: [...model.costHistory, cost]);

    _dataSource.products[sku] = ProductModel.fromEntity(updated).toMap();
  }

  @override
  Future<Product?> findBySku(String sku) async {
    final found = _dataSource.products[sku];
    if (found == null) {
      return null;
    }

    return ProductModel.fromMap(found);
  }

  @override
  Future<List<String>> listBrands() async {
    return _dataSource.brands.toList(growable: false)..sort();
  }

  @override
  Future<List<Product>> listProducts() async {
    return _dataSource.products.values
        .map(ProductModel.fromMap)
        .toList(growable: false);
  }

  @override
  Future<void> saveProduct(Product product) async {
    _dataSource.brands.add(product.brand);
    _dataSource.products[product.sku] = ProductModel.fromEntity(
      product,
    ).toMap();
  }

  @override
  Future<void> deleteProduct(String sku) async {
    _dataSource.products.remove(sku);
  }

  @override
  Future<void> updateStock(String sku, int newStock) async {
    final found = _dataSource.products[sku];
    if (found == null) {
      return;
    }

    final model = ProductModel.fromMap(found);
    final updated = model.copyWith(stock: newStock);
    _dataSource.products[sku] = ProductModel.fromEntity(updated).toMap();
  }

  @override
  Future<void> updateExpirationDate(
    String sku,
    DateTime newExpirationDate,
  ) async {
    final found = _dataSource.products[sku];
    if (found == null) {
      return;
    }

    final model = ProductModel.fromMap(found);
    final updated = model.copyWith(expirationDate: newExpirationDate);
    _dataSource.products[sku] = ProductModel.fromEntity(updated).toMap();
  }
}
