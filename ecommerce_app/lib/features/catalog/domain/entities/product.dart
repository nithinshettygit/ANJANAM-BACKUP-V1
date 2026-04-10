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
  });

  int? get sellableStock => availableStock ?? inventoryCount;
}

