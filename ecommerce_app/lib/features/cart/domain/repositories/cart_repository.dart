import '../entities/cart.dart';

abstract class CartRepository {
  Future<Cart> getCart();

  Future<Cart> addItem({
    required String productId,
    required int quantity,
  });

  Future<Cart> updateQuantity({
    required String productId,
    required int quantity,
  });

  Future<Cart> removeItem({
    required String productId,
  });

  Future<void> clearCart();
}

