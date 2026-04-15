import 'package:flutter/foundation.dart';

class CartItem {
  final String productId;
  /// When non-null, line maps to [product_variants] / checkout [variant_id].
  final String? variantId;
  final String? variantName;
  final String title;
  final List<String> imageUrls;
  final double unitPrice;
  final String currency;
  final int quantity;

  const CartItem({
    required this.productId,
    this.variantId,
    this.variantName,
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
            variantId == other.variantId &&
            variantName == other.variantName &&
            title == other.title &&
            listEquals(imageUrls, other.imageUrls) &&
            unitPrice == other.unitPrice &&
            currency == other.currency &&
            quantity == other.quantity;
  }

  @override
  int get hashCode => Object.hash(
        productId,
        variantId,
        variantName,
        title,
        Object.hashAll(imageUrls),
        unitPrice,
        currency,
        quantity,
      );
}

