class OrderItem {
  const OrderItem({
    required this.productSku,
    required this.quantity,
    required this.costPerItem,
    required this.expirationDate,
  });

  final String productSku;
  final int quantity;
  final double costPerItem;
  final DateTime expirationDate;
}
