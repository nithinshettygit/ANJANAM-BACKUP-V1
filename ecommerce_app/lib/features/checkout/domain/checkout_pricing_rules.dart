/// Delivery fee rules from [store_settings] (id = 1).
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

  double deliveryForSubtotal(double subtotal) {
    if (freeDeliveryAboveInr != null && subtotal >= freeDeliveryAboveInr!) {
      return 0;
    }
    return deliveryFeeInr;
  }
}
