import 'package:flutter_test/flutter_test.dart';
import 'package:ecommerce_app/features/cart/domain/entities/cart_item.dart';

void main() {
  CartItem item({int quantity = 1, int? stock}) => CartItem(
        productId: 'product-1',
        title: 'Product',
        imageUrls: const [],
        unitPrice: 100,
        currency: 'INR',
        quantity: quantity,
        availableStock: stock,
      );

  test('untracked stock remains eligible for checkout', () {
    expect(item().isOutOfStock, isFalse);
    expect(item().isAvailableForCheckout, isTrue);
  });

  test('zero stock makes a cart line unavailable', () {
    final cartItem = item(stock: 0);

    expect(cartItem.isOutOfStock, isTrue);
    expect(cartItem.isAvailableForCheckout, isFalse);
  });

  test('quantity above live stock makes a cart line unavailable', () {
    final cartItem = item(quantity: 3, stock: 2);

    expect(cartItem.isOutOfStock, isFalse);
    expect(cartItem.isAvailableForCheckout, isFalse);
  });

  test('quantity within live stock remains eligible', () {
    expect(item(quantity: 2, stock: 2).isAvailableForCheckout, isTrue);
  });
}
