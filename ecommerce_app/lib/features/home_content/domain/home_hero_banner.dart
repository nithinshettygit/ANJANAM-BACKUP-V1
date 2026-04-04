enum HomeBannerRedirectType {
  category,
  product,
  collection,
  externalLink,
  path,
  none;

  static HomeBannerRedirectType fromDb(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'product':
        return HomeBannerRedirectType.product;
      case 'collection':
        return HomeBannerRedirectType.collection;
      case 'external_link':
        return HomeBannerRedirectType.externalLink;
      case 'path':
        return HomeBannerRedirectType.path;
      case 'no_redirect':
        return HomeBannerRedirectType.none;
      default:
        return HomeBannerRedirectType.category;
    }
  }

  String get dbValue {
    switch (this) {
      case HomeBannerRedirectType.category:
        return 'category';
      case HomeBannerRedirectType.product:
        return 'product';
      case HomeBannerRedirectType.collection:
        return 'collection';
      case HomeBannerRedirectType.externalLink:
        return 'external_link';
      case HomeBannerRedirectType.path:
        return 'path';
      case HomeBannerRedirectType.none:
        return 'no_redirect';
    }
  }
}

class HomeHeroBanner {
  final String id;
  final String imageUrl;
  final HomeBannerRedirectType redirectType;
  final String redirectValue;
  final int sortOrder;

  const HomeHeroBanner({
    required this.id,
    required this.imageUrl,
    required this.redirectType,
    required this.redirectValue,
    required this.sortOrder,
  });

  factory HomeHeroBanner.fromJson(Map<String, dynamic> json) {
    return HomeHeroBanner(
      id: (json['id'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      redirectType: HomeBannerRedirectType.fromDb(json['redirect_type']?.toString()),
      redirectValue: (json['redirect_value'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
