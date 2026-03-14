import 'order_item.dart';

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.origin,
    required this.registeredAt,
    this.originIconUrl,
  });

  final String id;
  final List<OrderItem> items;
  final String origin;
  final DateTime registeredAt;
  final String? originIconUrl;
}
