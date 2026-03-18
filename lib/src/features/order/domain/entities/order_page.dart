import 'order.dart';

class OrderPage {
  const OrderPage({required this.items, this.nextCursor});

  final List<Order> items;
  final String? nextCursor;
}
