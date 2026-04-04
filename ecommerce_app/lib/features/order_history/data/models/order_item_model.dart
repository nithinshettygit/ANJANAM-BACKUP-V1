import 'package:ecommerce_app/core/formatting/inr_format.dart';

import '../../domain/entities/order_item.dart';

/// Data model mapped directly to the `order_items` table.
class OrderItemModel {
  final String? id;
  final String orderId;
  final String productId;
  final String title;
  final List<String> imageUrls;
  final double unitPrice;
  final String currency;
  final int quantity;

  const OrderItemModel({
    this.id,
    required this.orderId,
    required this.productId,
    required this.title,
    required this.imageUrls,
    required this.unitPrice,
    required this.currency,
    required this.quantity,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final imageUrlsDynamic = json['image_urls'];
    final imageUrls = imageUrlsDynamic is List
        ? imageUrlsDynamic.map((e) => e.toString()).toList()
        : <String>[];

    return OrderItemModel(
      id: () {
        final raw = json['id']?.toString().trim();
        return raw != null && raw.isNotEmpty ? raw : null;
      }(),
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      productId: (json['product_id'] ?? json['productId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      imageUrls: imageUrls,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      currency: currencyOrInr(json['currency']),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'product_id': productId,
        'title': title,
        'image_urls': imageUrls,
        'unit_price': unitPrice,
        'currency': currency,
        'quantity': quantity,
      };

  OrderItem toEntity() {
    return OrderItem(
      orderItemId: id,
      productId: productId,
      title: title,
      imageUrls: imageUrls,
      unitPrice: unitPrice,
      currency: currency,
      quantity: quantity,
    );
  }
}

