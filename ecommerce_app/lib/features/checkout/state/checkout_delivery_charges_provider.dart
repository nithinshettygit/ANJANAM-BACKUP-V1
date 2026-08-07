import 'dart:async';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product_delivery_charge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Same keying as payment-mode family: sorted product ids joined by unit separator.
String checkoutDeliveryChargesFamilyKey(Iterable<String> productIds) {
  final list = productIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  list.sort();
  return list.join('\x1f');
}

/// Loads per-product delivery charge modes for checkout preview.
/// Falls back to store-default for every id if column/migration is missing.
final checkoutDeliveryChargesProvider =
    FutureProvider.family<Map<String, ProductDeliveryCharge>, String>((ref, key) async {
  if (key.trim().isEmpty) return const {};
  final ids = key.split('\x1f').where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
  if (ids.isEmpty) return const {};

  final client = ref.watch(supabaseClientProvider);
  try {
    final rows = await client
        .from('products')
        .select('id, delivery_charge_mode, delivery_charge_inr')
        .inFilter('id', ids)
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('checkout delivery charges lookup'),
        );
    final map = <String, ProductDeliveryCharge>{};
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final mode = ProductDeliveryChargeModeDb.fromDb(m['delivery_charge_mode']?.toString());
      final fee = (m['delivery_charge_inr'] as num?)?.toDouble();
      map[id] = ProductDeliveryCharge(
        productId: id,
        mode: mode,
        customFeeInr: fee,
      );
    }
    for (final id in ids) {
      map.putIfAbsent(id, () => ProductDeliveryCharge.storeDefault(id));
    }
    return map;
  } catch (_) {
    return {for (final id in ids) id: ProductDeliveryCharge.storeDefault(id)};
  }
});
