import 'package:flutter/foundation.dart';

class CartItem {
  final String productId;
  final String title;
  final List<String> imageUrls;
  final double unitPrice;
  final String currency;
  final int quantity;

  const CartItem({
    required this.productId,
    required this.title,
    required this.imageUrls,
    required this.unitPrice,
    required this.currency,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CartItem &&
            productId == other.productId &&
            title == other.title &&
            listEquals(imageUrls, other.imageUrls) &&
            unitPrice == other.unitPrice &&
            currency == other.currency &&
            quantity == other.quantity;
  }

  @override
  int get hashCode => Object.hash(
        productId,
        title,
        Object.hashAll(imageUrls),
        unitPrice,
        currency,
        quantity,
      );
}

