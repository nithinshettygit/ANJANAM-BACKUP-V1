import 'dart:async';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product_payment_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stable key for [checkoutPaymentModesProvider] (never use raw [Set.identity] —
/// rebuilding with a new Set instance broke Riverpod.family caching in checkout).
String checkoutPaymentModesFamilyKey(Iterable<String> productIds) {
  final list = productIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  list.sort();
  return list.join('\x1f');
}

/// Fetches [ProductPaymentMode] per product id for checkout eligibility.
final checkoutPaymentModesProvider =
    FutureProvider.family<Map<String, ProductPaymentMode>, String>((ref, key) async {
  if (key.trim().isEmpty) return const {};
  final ids = key.split('\x1f').where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
  if (ids.isEmpty) return const {};

  final client = ref.watch(supabaseClientProvider);
  try {
    final rows = await client.from('products').select('id, payment_mode').inFilter('id', ids).timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException('checkout payment modes lookup'),
        );
    final raw = rows;
    final map = <String, ProductPaymentMode>{};
    for (final row in raw) {
      final m = Map<String, dynamic>.from(row);
      final id = m['id']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = ProductPaymentModeDb.fromDb(m['payment_mode']?.toString());
    }
    for (final id in ids) {
      map.putIfAbsent(id, () => ProductPaymentMode.both);
    }
    return map;
  } catch (_) {
    return {for (final id in ids) id: ProductPaymentMode.both};
  }
});

/// True when every product in [modes] allows COD.
bool checkoutCodAllowed(Map<String, ProductPaymentMode> modes) {
  if (modes.isEmpty) return true;
  return modes.values.every((m) => m.allowsCod);
}
