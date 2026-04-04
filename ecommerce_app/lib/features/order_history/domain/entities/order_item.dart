class OrderItem {
  /// Row id in `order_items` (required for returns after migration 030).
  final String? orderItemId;
  final String productId;
  final String title;
  final List<String> imageUrls;
  final double unitPrice;
  final String currency;
  final int quantity;

  const OrderItem({
    this.orderItemId,
    required this.productId,
    required this.title,
    required this.imageUrls,
    required this.unitPrice,
    required this.currency,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;
}

