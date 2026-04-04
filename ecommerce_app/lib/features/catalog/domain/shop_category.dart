/// Category row for Shop grid (Supabase [categories]) or active list for filters.
class ShopCategory {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int displayOrder;
  final int productCount;

  const ShopCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.displayOrder = 0,
    this.productCount = 0,
  });

  factory ShopCategory.fromShopCardJson(Map<String, dynamic> json) {
    final pc = json['product_count'];
    return ShopCategory(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      imageUrl: json['image_url']?.toString(),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      productCount: pc is num ? pc.toInt() : int.tryParse(pc?.toString() ?? '') ?? 0,
    );
  }

  factory ShopCategory.fromCategoriesTableJson(Map<String, dynamic> json) {
    final rawSlug = (json['slug'] ?? '').toString().trim();
    final rawName = (json['name'] ?? '').toString().trim();
    final slug = _stripInvisible(rawSlug);
    var name = _stripInvisible(rawName);
    if (name.isEmpty && slug.isNotEmpty) {
      name = derivedDisplayNameFromSlug(slug);
    }
    return ShopCategory(
      id: (json['id'] ?? '').toString().trim(),
      name: name,
      slug: slug,
      imageUrl: _nullableTrim(json['image_url']?.toString()),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      productCount: 0,
    );
  }

  static String _stripInvisible(String s) {
    return s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '').trim();
  }

  static String? _nullableTrim(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}

/// Title-style label from a DB slug (e.g. `photo` → `Photo`, `tea-gifts` → `Tea Gifts`).
String derivedDisplayNameFromSlug(String slug) {
  final t = slug.trim();
  if (t.isEmpty) return slug;
  return t
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map(
        (w) =>
            w.length == 1 ? w.toUpperCase() : '${w[0].toUpperCase()}${w.substring(1)}',
      )
      .join(' ');
}

/// Canonical key for matching [products.category] to [categories.slug] (lowercase, trimmed).
String normalizeProductCategoryKey(String? raw) {
  if (raw == null) return '';
  var s = raw.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '').trim().toLowerCase();
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}
