import '../entities/order.dart';
import '../entities/order_page.dart';
import '../entities/order_origin.dart';

abstract interface class OrderRepository {
  Future<void> saveOrder(Order order);
  Future<void> deleteOrder(String id);
  Future<Order?> findById(String id);
  Future<List<Order>> listOrders();
  Future<OrderPage> listOrdersPage({required int limit, String? afterCursor});
  Future<List<OrderOrigin>> listOrigins();
  Future<void> addOrigin(OrderOrigin origin);
}
