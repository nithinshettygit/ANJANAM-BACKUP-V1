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
  final String? hsnCode;
  final String? taxStatus;
  final double? taxableValue;
  final double? gstRate;
  final double? cgstAmount;
  final double? sgstAmount;
  final double? igstAmount;
  final bool? priceIncludesGst;

  final String? variantId;

  const OrderItemModel({
    this.id,
    required this.orderId,
    required this.productId,
    this.variantId,
    required this.title,
    required this.imageUrls,
    required this.unitPrice,
    required this.currency,
    required this.quantity,
    this.hsnCode,
    this.taxStatus,
    this.taxableValue,
    this.gstRate,
    this.cgstAmount,
    this.sgstAmount,
    this.igstAmount,
    this.priceIncludesGst,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final imageUrlsDynamic = json['image_urls'];
    final imageUrls = imageUrlsDynamic is List
        ? imageUrlsDynamic.map((e) => e.toString()).toList()
        : <String>[];

    final rawVid = json['variant_id'] ?? json['variantId'];
    final vid = rawVid?.toString().trim();

    double? readDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) return null;
        return double.tryParse(s);
      }
      return null;
    }

    return OrderItemModel(
      id: () {
        final raw = json['id']?.toString().trim();
        return raw != null && raw.isNotEmpty ? raw : null;
      }(),
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      productId: (json['product_id'] ?? json['productId'] ?? '').toString(),
      variantId: vid?.isNotEmpty == true ? vid : null,
      title: (json['title'] ?? '').toString(),
      imageUrls: imageUrls,
      unitPrice: readDouble(json['unit_price']) ?? 0.0,
      currency: currencyOrInr(json['currency']),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      hsnCode: json['hsn_code']?.toString().trim().isEmpty == true
          ? null
          : json['hsn_code']?.toString().trim(),
      taxStatus: json['tax_status']?.toString(),
      taxableValue: readDouble(json['taxable_value']),
      gstRate: readDouble(json['gst_rate']),
      cgstAmount: readDouble(json['cgst_amount']),
      sgstAmount: readDouble(json['sgst_amount']),
      igstAmount: readDouble(json['igst_amount']),
      priceIncludesGst: json['price_includes_gst'] as bool?,
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
      variantId: variantId,
      productId: productId,
      title: title,
      imageUrls: imageUrls,
      unitPrice: unitPrice,
      currency: currency,
      quantity: quantity,
      hsnCode: hsnCode,
      taxStatus: taxStatus,
      taxableValue: taxableValue,
      gstRate: gstRate,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      priceIncludesGst: priceIncludesGst,
    );
  }
}
