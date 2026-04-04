class HomeTopCategoryItem {
  final String id;
  final String label;
  final String iconUrl;
  final String categorySlug;
  final int sortOrder;

  const HomeTopCategoryItem({
    required this.id,
    required this.label,
    required this.iconUrl,
    required this.categorySlug,
    required this.sortOrder,
  });

  factory HomeTopCategoryItem.fromJson(Map<String, dynamic> json) {
    return HomeTopCategoryItem(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      iconUrl: (json['icon_url'] ?? '').toString(),
      categorySlug: (json['category_slug'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
