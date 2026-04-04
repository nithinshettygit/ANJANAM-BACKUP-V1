import 'package:flutter/foundation.dart';

/// How the storefront autocomplete matched this product (from RPC `match_kind`).
enum SuggestionMatchKind {
  titlePrefix,
  title,
  category,
  description,
  tag,
  unknown,
}

SuggestionMatchKind suggestionMatchKindFromApi(String? raw) {
  switch (raw) {
    case 'title_prefix':
      return SuggestionMatchKind.titlePrefix;
    case 'title':
      return SuggestionMatchKind.title;
    case 'category':
      return SuggestionMatchKind.category;
    case 'description':
      return SuggestionMatchKind.description;
    case 'tag':
      return SuggestionMatchKind.tag;
    default:
      return SuggestionMatchKind.unknown;
  }
}

/// Row from `products` for autocomplete (display name is [name] / `title` in Supabase).
@immutable
class ProductSuggestion {
  final String id;
  /// Product title (`products.title`).
  final String name;
  /// URL slug when present; this schema often navigates by [id] only.
  final String? slug;
  /// Category label (`products.category`), not a UUID foreign key.
  final String? categorySlug;
  final SuggestionMatchKind matchKind;

  const ProductSuggestion({
    required this.id,
    required this.name,
    this.slug,
    this.categorySlug,
    this.matchKind = SuggestionMatchKind.unknown,
  });

  factory ProductSuggestion.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? json['name'] ?? '').toString();
    return ProductSuggestion(
      id: (json['id'] ?? '').toString(),
      name: title,
      slug: json['slug']?.toString(),
      categorySlug: json['category']?.toString(),
      matchKind: suggestionMatchKindFromApi(json['match_kind']?.toString()),
    );
  }
}
