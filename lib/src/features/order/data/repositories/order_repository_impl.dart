import '../../domain/entities/order.dart';
import '../../domain/entities/order_page.dart';
import '../../domain/entities/order_origin.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/order_model.dart';
import '../../../shared/data/datasources/in_memory_erp_datasource.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._dataSource);

  final InMemoryErpDataSource _dataSource;
  static const String _cursorSeparator = '|';

  @override
  Future<Order?> findById(String id) async {
    final found = _dataSource.orders[id];
    if (found == null) {
      return null;
    }

    return OrderModel.fromMap(found);
  }

  @override
  Future<List<Order>> listOrders() async {
    return _dataSource.orders.values
        .map(OrderModel.fromMap)
        .toList(growable: false);
  }

  @override
  Future<OrderPage> listOrdersPage({
    required int limit,
    String? afterCursor,
  }) async {
    final ordered =
        _dataSource.orders.values
            .map(OrderModel.fromMap)
            .toList(growable: false)
          ..sort((a, b) {
            final byDate = b.registeredAt.compareTo(a.registeredAt);
            if (byDate != 0) {
              return byDate;
            }
            return b.id.compareTo(a.id);
          });

    var startIndex = 0;
    if (afterCursor != null && afterCursor.isNotEmpty) {
      final parts = afterCursor.split(_cursorSeparator);
      if (parts.length == 2) {
        final cursorDate = DateTime.tryParse(parts[0]);
        final cursorId = parts[1];
        if (cursorDate != null) {
          startIndex =
              ordered.indexWhere(
                (o) =>
                    o.registeredAt.toIso8601String() ==
                        cursorDate.toIso8601String() &&
                    o.id == cursorId,
              ) +
              1;
        }
      }
    }

    final safeStart = startIndex < 0 ? 0 : startIndex;
    final endIndex = safeStart + limit > ordered.length
        ? ordered.length
        : safeStart + limit;
    final items = ordered.sublist(safeStart, endIndex);
    final nextCursor = endIndex >= ordered.length || items.isEmpty
        ? null
        : '${items.last.registeredAt.toIso8601String()}$_cursorSeparator${items.last.id}';

    return OrderPage(items: items, nextCursor: nextCursor);
  }

  @override
  Future<List<OrderOrigin>> listOrigins() async {
    return _dataSource.origins.entries
        .map((e) => OrderOrigin(name: e.key, iconUrl: e.value))
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> addOrigin(OrderOrigin origin) async {
    final normalized = origin.name.trim();
    if (normalized.isEmpty) {
      return;
    }
    _dataSource.origins[normalized] = origin.iconUrl;
  }

  @override
  Future<void> saveOrder(Order order) async {
    _dataSource.origins[order.origin] = order.originIconUrl;
    _dataSource.orders[order.id] = OrderModel.fromEntity(order).toMap();
  }

  @override
  Future<void> deleteOrder(String id) async {
    _dataSource.orders.remove(id);
  }
}
