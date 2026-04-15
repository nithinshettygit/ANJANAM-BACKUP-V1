class ProductVariant {
  final String id;
  final String productId;
  final String variantType;
  final String variantName;
  final double price;
  final int stockQuantity;
  final int? availableStock;
  final String imageUrl;
  final String? sku;
  final double? shippingWeightKg;
  final String? shippingDimensionsCm;
  final bool isDefault;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.variantType,
    required this.variantName,
    required this.price,
    required this.stockQuantity,
    this.availableStock,
    required this.imageUrl,
    this.sku,
    this.shippingWeightKg,
    this.shippingDimensionsCm,
    required this.isDefault,
  });

  int? get sellableStock => availableStock ?? stockQuantity;

  factory ProductVariant.fromRow(
    Map<String, dynamic> json, {
    required String productId,
  }) {
    bool readBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v?.toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    int? avail(dynamic v) {
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

    return ProductVariant(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? productId).toString(),
      variantType: (json['variant_type'] ?? '').toString(),
      variantName: (json['variant_name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      availableStock: avail(json['available_stock']),
      imageUrl: (json['image_url'] ?? '').toString(),
      sku: json['sku']?.toString(),
      shippingWeightKg: (json['weight'] as num?)?.toDouble(),
      shippingDimensionsCm: () {
        final t = json['dimensions']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      isDefault: readBool(json['is_default']),
    );
  }
}
