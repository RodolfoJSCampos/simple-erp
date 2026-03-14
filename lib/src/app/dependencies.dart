import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/order/data/repositories/firestore_order_repository.dart';
import '../features/order/data/repositories/order_repository_impl.dart';
import '../features/order/domain/usecases/create_order.dart';
import '../features/order/domain/usecases/add_origin.dart';
import '../features/order/domain/usecases/delete_order.dart';
import '../features/order/domain/usecases/list_origins.dart';
import '../features/order/domain/usecases/list_orders.dart';
import '../features/order/presentation/controllers/order_controller.dart';
import '../features/product/data/repositories/firestore_product_repository.dart';
import '../features/product/data/repositories/product_repository_impl.dart';
import '../features/product/domain/usecases/add_brand.dart';
import '../features/product/domain/usecases/create_product.dart';
import '../features/product/domain/usecases/delete_product.dart';
import '../features/product/domain/usecases/list_brands.dart';
import '../features/product/domain/usecases/list_products.dart';
import '../features/product/domain/usecases/register_product_cost.dart';
import '../features/product/domain/usecases/update_product_expiration.dart';
import '../features/product/domain/usecases/update_product_stock.dart';
import '../features/product/domain/repositories/product_repository.dart';
import '../features/product/presentation/controllers/product_controller.dart';
import '../features/order/domain/repositories/order_repository.dart';
import '../features/shared/data/datasources/in_memory_erp_datasource.dart';

class AppDependencies {
  AppDependencies._({
    required this.productController,
    required this.orderController,
    required this.usingFirebase,
  });

  final ProductController productController;
  final OrderController orderController;
  final bool usingFirebase;

  factory AppDependencies.build({required bool useFirebase}) {
    late final ProductRepository productRepository;
    late final OrderRepository orderRepository;

    if (useFirebase) {
      final firestore = FirebaseFirestore.instance;
      productRepository = FirestoreProductRepository(firestore);
      orderRepository = FirestoreOrderRepository(firestore);
    } else {
      final dataSource = InMemoryErpDataSource();
      productRepository = ProductRepositoryImpl(dataSource);
      orderRepository = OrderRepositoryImpl(dataSource);
    }

    final productController = ProductController(
      createProduct: CreateProduct(productRepository),
      listProducts: ListProducts(productRepository),
      listBrands: ListBrands(productRepository),
      addBrand: AddBrand(productRepository),
      deleteProduct: DeleteProduct(productRepository),
      registerProductCost: RegisterProductCost(productRepository),
      updateProductExpiration: UpdateProductExpiration(productRepository),
      updateProductStock: UpdateProductStock(productRepository),
    );

    final orderController = OrderController(
      createOrder: CreateOrder(orderRepository),
      listOrders: ListOrders(orderRepository),
      listOrigins: ListOrigins(orderRepository),
      addOrigin: AddOrigin(orderRepository),
      deleteOrder: DeleteOrder(orderRepository),
    );

    return AppDependencies._(
      productController: productController,
      orderController: orderController,
      usingFirebase: useFirebase,
    );
  }
}
