import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/checkout_pricing_rules.dart';

final checkoutPricingRulesProvider =
    FutureProvider.autoDispose<CheckoutPricingRules>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final row = await client
        .from('store_settings')
        .select('delivery_fee_inr, free_delivery_above_inr')
        .eq('id', 1)
        .maybeSingle();
    return CheckoutPricingRules(
      deliveryFeeInr: (row?['delivery_fee_inr'] as num?)?.toDouble() ?? 49,
      freeDeliveryAboveInr:
          (row?['free_delivery_above_inr'] as num?)?.toDouble(),
    );
  } catch (_) {
    return CheckoutPricingRules.fallback;
  }
});
