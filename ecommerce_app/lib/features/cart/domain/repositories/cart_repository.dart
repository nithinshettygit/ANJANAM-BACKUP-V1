import '../entities/cart.dart';

abstract class CartRepository {
  Future<Cart> getCart();

  Future<Cart> addItem({
    required String productId,
    required int quantity,
    String? variantId,
  });

  Future<Cart> updateQuantity({
    required String productId,
    String? variantId,
    required int quantity,
  });

  Future<Cart> removeItem({
    required String productId,
    String? variantId,
  });

  Future<void> clearCart();
}

