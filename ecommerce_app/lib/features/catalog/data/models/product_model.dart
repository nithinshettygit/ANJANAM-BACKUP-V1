import 'package:ecommerce_app/core/formatting/inr_format.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';

/// Data model mapped directly to the `products` table.
///
/// Update column names to match your Supabase schema if they differ.
class ProductModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final List<String> imageUrls;
  final String? category;
  final List<String> tags;
  final int? inventoryCount;
  /// When present (generated column `available_stock`), use for customer-facing stock checks.
  final int? availableStock;
  final DateTime? createdAt;
  final int displayDiscountPercent;
  final double? averageRating;
  final int totalReviews;
  final int totalWrittenReviews;
  final double? shippingWeightKg;
  final String? shippingDimensionsCm;
  final List<ProductVariant> variants;

  const ProductModel({
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
  });

  static List<ProductVariant> _variantsFromJson(
    Map<String, dynamic> json,
    String productId,
  ) {
    final raw = json['product_variants'];
    if (raw is! List) return const [];
    final out = <ProductVariant>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(ProductVariant.fromRow(e, productId: productId));
      } else if (e is Map) {
        out.add(ProductVariant.fromRow(Map<String, dynamic>.from(e), productId: productId));
      }
    }
    out.sort((a, b) => a.variantName.toLowerCase().compareTo(b.variantName.toLowerCase()));
    return out;
  }

  /// PostgREST / JSON may send counts as int, double, or (rarely) string.
  static int? inventoryCountFromJson(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }
    return null;
  }

  /// Prefer [availableStock] when the API exposes it (reservation-aware); else [inventoryCount].
  int? get sellableQuantity => availableStock ?? inventoryCount;

  static int displayDiscountPercentFromJson(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.clamp(0, 99);
    if (v is num) return v.round().clamp(0, 99);
    return 0;
  }

  static double? averageRatingFromJson(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int totalReviewsFromJson(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final imageUrlsDynamic = json['image_urls'];
    final imageUrls = imageUrlsDynamic is List
        ? imageUrlsDynamic.map((e) => e.toString()).toList()
        : <String>[];
    final tagsDynamic = json['tags'];
    final tags = tagsDynamic is List
        ? tagsDynamic.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final id = (json['id'] ?? '').toString();
    return ProductModel(
      id: id,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: currencyOrInr(json['currency']),
      imageUrls: imageUrls,
      category: json['category']?.toString(),
      tags: tags,
      inventoryCount: inventoryCountFromJson(json['inventory_count']),
      availableStock: inventoryCountFromJson(json['available_stock']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      displayDiscountPercent: displayDiscountPercentFromJson(json['display_discount_percent']),
      averageRating: averageRatingFromJson(json['average_rating']),
      totalReviews: totalReviewsFromJson(json['total_reviews']),
      totalWrittenReviews: totalReviewsFromJson(json['total_written_reviews']),
      shippingWeightKg: (json['weight'] as num?)?.toDouble(),
      shippingDimensionsCm: () {
        final t = json['dimensions']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      variants: _variantsFromJson(json, id),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      'image_urls': imageUrls,
      'category': category,
      'tags': tags,
      'inventory_count': inventoryCount,
      'available_stock': availableStock,
      'created_at': createdAt?.toIso8601String(),
      'display_discount_percent': displayDiscountPercent,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'total_written_reviews': totalWrittenReviews,
      'weight': shippingWeightKg,
      'dimensions': shippingDimensionsCm,
      'product_variants': variants
          .map(
            (v) => {
              'id': v.id,
              'product_id': v.productId,
              'variant_type': v.variantType,
              'variant_name': v.variantName,
              'price': v.price,
              'stock_quantity': v.stockQuantity,
              'available_stock': v.availableStock,
              'image_url': v.imageUrl,
              'sku': v.sku,
              'is_default': v.isDefault,
            },
          )
          .toList(),
    };
  }

  Product toEntity() {
    return Product(
      id: id,
      title: title,
      description: description,
      price: price,
      currency: currency,
      imageUrls: imageUrls,
      category: category,
      tags: tags,
      inventoryCount: inventoryCount,
      availableStock: availableStock,
      createdAt: createdAt,
      displayDiscountPercent: displayDiscountPercent,
      averageRating: averageRating,
      totalReviews: totalReviews,
      totalWrittenReviews: totalWrittenReviews,
      shippingWeightKg: shippingWeightKg,
      shippingDimensionsCm: shippingDimensionsCm,
      variants: variants,
    );
  }
}

