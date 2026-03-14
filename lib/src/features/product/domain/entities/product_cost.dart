class ProductCost {
  const ProductCost({
    required this.orderId,
    required this.value,
    required this.registeredAt,
    required this.origin,
  });

  final String orderId;
  final double value;
  final DateTime registeredAt;
  final String origin;
}
