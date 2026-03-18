import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_cost.dart';
import '../../domain/entities/product_page.dart';
import '../../domain/usecases/add_brand.dart';
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/list_brands.dart';
import '../../domain/usecases/list_products.dart';
import '../../domain/usecases/list_products_page.dart';
import '../../domain/usecases/register_product_cost.dart';
import '../../domain/usecases/update_product_expiration.dart';
import '../../domain/usecases/update_product_stock.dart';

class ProductController {
  ProductController({
    required CreateProduct createProduct,
    required ListProducts listProducts,
    required ListProductsPage listProductsPage,
    required ListBrands listBrands,
    required AddBrand addBrand,
    required DeleteProduct deleteProduct,
    required RegisterProductCost registerProductCost,
    required UpdateProductExpiration updateProductExpiration,
    required UpdateProductStock updateProductStock,
  }) : _createProduct = createProduct,
       _listProducts = listProducts,
       _listProductsPage = listProductsPage,
       _listBrands = listBrands,
       _addBrand = addBrand,
       _deleteProduct = deleteProduct,
       _registerProductCost = registerProductCost,
       _updateProductExpiration = updateProductExpiration,
       _updateProductStock = updateProductStock;

  final CreateProduct _createProduct;
  final ListProducts _listProducts;
  final ListProductsPage _listProductsPage;
  final ListBrands _listBrands;
  final AddBrand _addBrand;
  final DeleteProduct _deleteProduct;
  final RegisterProductCost _registerProductCost;
  final UpdateProductExpiration _updateProductExpiration;
  final UpdateProductStock _updateProductStock;

  Future<void> create(Product product) => _createProduct(product);

  Future<List<Product>> list() => _listProducts(const NoParams());

  Future<ProductPage> listPage({required int limit, String? afterSku}) {
    return _listProductsPage(
      ListProductsPageParams(limit: limit, afterSku: afterSku),
    );
  }

  Future<List<String>> listBrands() => _listBrands(const NoParams());

  Future<void> createBrand(String brand) => _addBrand(brand);

  Future<void> delete(String sku) => _deleteProduct(sku);

  Future<void> registerCost({required String sku, required ProductCost cost}) {
    return _registerProductCost(
      RegisterProductCostParams(sku: sku, cost: cost),
    );
  }

  Future<void> updateStock({required String sku, required int newStock}) {
    return _updateProductStock(
      UpdateProductStockParams(sku: sku, newStock: newStock),
    );
  }

  Future<void> updateExpirationDate({
    required String sku,
    required DateTime newExpirationDate,
  }) {
    return _updateProductExpiration(
      UpdateProductExpirationParams(
        sku: sku,
        newExpirationDate: newExpirationDate,
      ),
    );
  }
}
