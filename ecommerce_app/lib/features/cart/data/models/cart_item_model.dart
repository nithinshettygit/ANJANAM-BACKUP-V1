import 'package:ecommerce_app/core/formatting/inr_format.dart';

import '../../domain/entities/cart_item.dart';

/// Data model mapped directly to the `cart_items` table.
class CartItemModel {
  final String cartId;
  final String productId;
  final String? variantId;
  final int quantity;
  final double unitPrice;
  final String currency;

  const CartItemModel({
    required this.cartId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.unitPrice,
    required this.currency,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final rawVid = json['variant_id'] ?? json['variantId'];
    final vid = rawVid?.toString().trim();
    return CartItemModel(
      cartId: (json['cart_id'] ?? json['cartId'] ?? '').toString(),
      productId: (json['product_id'] ?? json['productId'] ?? '').toString(),
      variantId: vid?.isNotEmpty == true ? vid : null,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      currency: currencyOrInr(json['currency']),
    );
  }

  Map<String, dynamic> toJson() => {
        'cart_id': cartId,
        'product_id': productId,
        if (variantId != null) 'variant_id': variantId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'currency': currency,
      };

  CartItem toEntity({
    required String title,
    required List<String> imageUrls,
    String? variantName,
    int? availableStock,
  }) {
    return CartItem(
      productId: productId,
      variantId: variantId,
      variantName: variantName,
      title: title,
      imageUrls: imageUrls,
      unitPrice: unitPrice,
      currency: currency,
      quantity: quantity,
      availableStock: availableStock,
    );
  }
}
