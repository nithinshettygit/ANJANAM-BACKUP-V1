/// Per-product delivery override relative to store-wide delivery settings.
enum ProductDeliveryChargeMode {
  /// Use [store_settings] fee + free-above threshold.
  storeDefault,

  /// This product contributes ₹0 to the max-fee calculation.
  free,

  /// Use fixed [ProductDeliveryCharge.customFeeInr].
  custom,
}

extension ProductDeliveryChargeModeDb on ProductDeliveryChargeMode {
  String toDbValue() {
    switch (this) {
      case ProductDeliveryChargeMode.free:
        return 'free';
      case ProductDeliveryChargeMode.custom:
        return 'custom';
      case ProductDeliveryChargeMode.storeDefault:
        return 'default';
    }
  }

  static ProductDeliveryChargeMode fromDb(String? raw) {
    final v = (raw ?? 'default').trim().toLowerCase();
    if (v == 'free') return ProductDeliveryChargeMode.free;
    if (v == 'custom') return ProductDeliveryChargeMode.custom;
    return ProductDeliveryChargeMode.storeDefault;
  }
}

/// One product's delivery rule (used for order fee = max of candidates).
class ProductDeliveryCharge {
  final String productId;
  final ProductDeliveryChargeMode mode;
  final double? customFeeInr;

  const ProductDeliveryCharge({
    required this.productId,
    required this.mode,
    this.customFeeInr,
  });

  factory ProductDeliveryCharge.storeDefault(String productId) =>
      ProductDeliveryCharge(
        productId: productId,
        mode: ProductDeliveryChargeMode.storeDefault,
      );
}
