import 'product_delivery_charge.dart';
import 'product_payment_mode.dart';
import 'product_variant.dart';

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final List<String> imageUrls;
  final String? category;
  final List<String> tags;
  final int? inventoryCount;
  final int? availableStock;
  final DateTime? createdAt;
  /// Storefront card promo: 0 = hide "% OFF" and strikethrough list price.
  final int displayDiscountPercent;

  /// Denormalized from reviews (visible only). Null when no ratings yet.
  final double? averageRating;
  final int totalReviews;
  final int totalWrittenReviews;
  /// Default shipping weight in kg set by admin on product.
  final double? shippingWeightKg;
  /// Default package dimensions in cm (LxWxH), e.g. `20x15x10`.
  final String? shippingDimensionsCm;

  /// Phase 1: at most one [variantType] across all variants (enforced in DB).
  final List<ProductVariant> variants;

  final ProductPaymentMode paymentMode;

  /// Delivery: store default / free / custom ([deliveryChargeInr]).
  final ProductDeliveryChargeMode deliveryChargeMode;
  final double? deliveryChargeInr;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.imageUrls,
    this.category,
    this.tags = const [],
    this.inventoryCount,
    this.availableStock,
    this.createdAt,
    this.displayDiscountPercent = 0,
    this.averageRating,
    this.totalReviews = 0,
    this.totalWrittenReviews = 0,
    this.shippingWeightKg,
    this.shippingDimensionsCm,
    this.variants = const [],
    this.paymentMode = ProductPaymentMode.both,
    this.deliveryChargeMode = ProductDeliveryChargeMode.storeDefault,
    this.deliveryChargeInr,
  });

  bool get allowsCod => paymentMode.allowsCod;

  int? get sellableStock => availableStock ?? inventoryCount;

  bool get hasVariants => variants.isNotEmpty;

  String? get variantTypeLabel =>
      variants.isEmpty ? null : variants.first.variantType.trim();

  ProductVariant? get defaultVariant {
    if (variants.isEmpty) return null;
    for (final v in variants) {
      if (v.isDefault) return v;
    }
    return variants.first;
  }

  Product copyWith({
    double? price,
    List<String>? imageUrls,
    int? availableStock,
    int? inventoryCount,
  }) {
    return Product(
      id: id,
      title: title,
      description: description,
      price: price ?? this.price,
      currency: currency,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category,
      tags: tags,
      inventoryCount: inventoryCount ?? this.inventoryCount,
      availableStock: availableStock ?? this.availableStock,
      createdAt: createdAt,
      displayDiscountPercent: displayDiscountPercent,
      averageRating: averageRating,
      totalReviews: totalReviews,
      totalWrittenReviews: totalWrittenReviews,
      shippingWeightKg: shippingWeightKg,
      shippingDimensionsCm: shippingDimensionsCm,
      variants: variants,
      paymentMode: paymentMode,
      deliveryChargeMode: deliveryChargeMode,
      deliveryChargeInr: deliveryChargeInr,
    );
  }
}
