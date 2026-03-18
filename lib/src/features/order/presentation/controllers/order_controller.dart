import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_page.dart';
import '../../domain/entities/order_origin.dart';
import '../../domain/usecases/add_origin.dart';
import '../../domain/usecases/create_order.dart';
import '../../domain/usecases/delete_order.dart';
import '../../domain/usecases/list_origins.dart';
import '../../domain/usecases/list_orders.dart';
import '../../domain/usecases/list_orders_page.dart';

class OrderController {
  OrderController({
    required CreateOrder createOrder,
    required ListOrders listOrders,
    required ListOrdersPage listOrdersPage,
    required ListOrigins listOrigins,
    required AddOrigin addOrigin,
    required DeleteOrder deleteOrder,
  }) : _createOrder = createOrder,
       _listOrders = listOrders,
       _listOrdersPage = listOrdersPage,
       _listOrigins = listOrigins,
       _addOrigin = addOrigin,
       _deleteOrder = deleteOrder;

  final CreateOrder _createOrder;
  final ListOrders _listOrders;
  final ListOrdersPage _listOrdersPage;
  final ListOrigins _listOrigins;
  final AddOrigin _addOrigin;
  final DeleteOrder _deleteOrder;

  Future<void> create(Order order) => _createOrder(order);

  Future<List<Order>> list() => _listOrders(const NoParams());

  Future<OrderPage> listPage({required int limit, String? afterCursor}) {
    return _listOrdersPage(
      ListOrdersPageParams(limit: limit, afterCursor: afterCursor),
    );
  }

  Future<List<OrderOrigin>> listOrigins() => _listOrigins(const NoParams());

  Future<void> createOrigin(OrderOrigin origin) => _addOrigin(origin);

  Future<void> delete(String id) => _deleteOrder(id);
}
