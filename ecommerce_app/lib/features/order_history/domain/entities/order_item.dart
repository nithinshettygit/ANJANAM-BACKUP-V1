class OrderItem {
  /// Row id in `order_items` (required for returns after migration 030).
  final String? orderItemId;
  final String? variantId;
  final String productId;
  final String title;
  final List<String> imageUrls;
  final double unitPrice;
  final String currency;
  final int quantity;
  final String? hsnCode;
  final String? taxStatus;
  final double? taxableValue;
  final double? gstRate;
  final double? cgstAmount;
  final double? sgstAmount;
  final double? igstAmount;
  final bool? priceIncludesGst;

  const OrderItem({
    this.orderItemId,
    this.variantId,
    required this.productId,
    required this.title,
    required this.imageUrls,
    required this.unitPrice,
    required this.currency,
    required this.quantity,
    this.hsnCode,
    this.taxStatus,
    this.taxableValue,
    this.gstRate,
    this.cgstAmount,
    this.sgstAmount,
    this.igstAmount,
    this.priceIncludesGst,
  });

  double get lineTotal => unitPrice * quantity;
}
