/// Checkout payment options allowed for a product (`products.payment_mode`).
enum ProductPaymentMode {
  /// Cash on delivery and Razorpay (default for existing products).
  both,

  /// Razorpay only — COD hidden and rejected server-side.
  onlineOnly,
}

abstract final class ProductPaymentModeMessages {
  static const String onlineOnlyCheckout =
      'This product is available only via online payment.';
  static const String onlineOnlyCart =
      'One or more items in your cart are available only via online payment.';
}

extension ProductPaymentModeDb on ProductPaymentMode {
  bool get allowsCod => this == ProductPaymentMode.both;

  String toDbValue() =>
      this == ProductPaymentMode.onlineOnly ? 'online_only' : 'both';

  static ProductPaymentMode fromDb(String? raw) {
    final v = (raw ?? 'both').trim().toLowerCase();
    if (v == 'online_only' || v == 'onlineonly' || v == 'online-only') {
      return ProductPaymentMode.onlineOnly;
    }
    return ProductPaymentMode.both;
  }
}
