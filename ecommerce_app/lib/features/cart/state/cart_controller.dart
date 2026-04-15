import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import '../data/services/supabase_cart_service.dart';
import '../domain/entities/cart.dart';
import '../domain/repositories/cart_repository.dart';

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => SupabaseCartService(ref.watch(supabaseClientProvider)),
);

class CartController extends AsyncNotifier<Cart> {
  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  Future<Cart> build() async {
    return _repo.getCart();
  }

  Future<void> addItem({
    required String productId,
    required int quantity,
    String? variantId,
  }) async {
    // No [AsyncLoading]: keep previous cart visible until success. On failure, state unchanged.
    final updated = await _repo.addItem(
      productId: productId,
      quantity: quantity,
      variantId: variantId,
    );
    state = AsyncData(updated);
  }

  Future<void> updateQuantity({
    required String productId,
    String? variantId,
    required int quantity,
  }) async {
    final updated = await _repo.updateQuantity(
      productId: productId,
      variantId: variantId,
      quantity: quantity,
    );
    state = AsyncData(updated);
  }

  Future<void> removeItem({
    required String productId,
    String? variantId,
  }) async {
    final updated = await _repo.removeItem(productId: productId, variantId: variantId);
    state = AsyncData(updated);
  }

  Future<void> clearCart() async {
    await _repo.clearCart();
    state = AsyncData(await _repo.getCart());
  }
}

final cartControllerProvider =
    AsyncNotifierProvider<CartController, Cart>(CartController.new);

/// Sum of line quantities — use for cart badges (rebuilds only when [Cart] value changes).
final cartTotalQuantityProvider = Provider<int>((ref) {
  final cart = ref.watch(cartControllerProvider.select((a) => a.value));
  if (cart == null) return 0;
  return cart.items.fold<int>(0, (s, e) => s + e.quantity);
});

/// Distinct SKUs in cart (optional: “3 products” style).
final cartLineCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartControllerProvider.select((a) => a.value));
  return cart?.items.length ?? 0;
});


