/// Delivery fee rules from [store_settings] (id = 1).
///
/// Order fee = max of per-product candidates (see [deliveryForCart]).
class CheckoutPricingRules {
  final double deliveryFeeInr;
  final double? freeDeliveryAboveInr;

  const CheckoutPricingRules({
    required this.deliveryFeeInr,
    required this.freeDeliveryAboveInr,
  });

  static const CheckoutPricingRules fallback = CheckoutPricingRules(
    deliveryFeeInr: 49,
    freeDeliveryAboveInr: 500,
  );

  /// Store-only path (all lines use default mode). Kept for simple previews.
  double deliveryForSubtotal(double subtotal) {
    return deliveryForCart(
      subtotal: subtotal,
      productModes: const [],
    );
  }

  /// Matches DB [product_delivery_fee_candidate] + max over lines.
  ///
  /// * free → 0
  /// * custom → custom amount (≥ 0)
  /// * default / empty modes → store fee unless free-above applies to [subtotal]
  double deliveryForCart({
    required double subtotal,
    required Iterable<({String mode, double? customFeeInr})> productModes,
  }) {
    final storeDefault = _storeDefaultCandidate(subtotal);
    final modes = productModes.toList();
    if (modes.isEmpty) {
      return storeDefault;
    }
    var maxFee = 0.0;
    for (final m in modes) {
      final mode = (m.mode).trim().toLowerCase();
      double candidate;
      if (mode == 'free') {
        candidate = 0;
      } else if (mode == 'custom') {
        final fee = m.customFeeInr ?? 0;
        candidate = fee < 0 ? 0 : fee;
      } else {
        candidate = storeDefault;
      }
      if (candidate > maxFee) maxFee = candidate;
    }
    return maxFee;
  }

  double _storeDefaultCandidate(double subtotal) {
    if (freeDeliveryAboveInr != null && subtotal >= freeDeliveryAboveInr!) {
      return 0;
    }
    return deliveryFeeInr < 0 ? 0 : deliveryFeeInr;
  }
}
