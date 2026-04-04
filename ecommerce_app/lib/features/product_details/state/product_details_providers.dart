import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/entities/product.dart';
import '../../catalog/state/product_list_providers.dart';
import '../domain/entities/product_detail.dart';

/// Keeps parsed product details in memory briefly after leaving the screen to avoid
/// duplicate fetches when popping back (autoDispose closes the link after ~3 min idle).
final productDetailsProvider =
    FutureProvider.autoDispose.family<ProductDetail, String>(
  (ref, productId) async {
    ref.watch(storefrontCatalogRevisionProvider);

    final link = ref.keepAlive();
    Timer? disposeTimer;
    ref.onCancel(() {
      disposeTimer?.cancel();
      disposeTimer = Timer(const Duration(minutes: 3), link.close);
    });
    ref.onResume(() {
      disposeTimer?.cancel();
      disposeTimer = null;
    });
    ref.onDispose(() => disposeTimer?.cancel());

    final product = await ref
        .read(productRepositoryProvider)
        .fetchProductById(productId);

    return ProductDetail.fromProduct(product);
  },
);

class SimilarProductsQuery {
  final String currentProductId;
  final String? category;
  final String? title;
  final List<String> tags;
  final int limit;

  const SimilarProductsQuery({
    required this.currentProductId,
    this.category,
    this.title,
    this.tags = const [],
    this.limit = 8,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimilarProductsQuery &&
        other.currentProductId == currentProductId &&
        other.category?.trim().toLowerCase() == category?.trim().toLowerCase() &&
        other.title?.trim().toLowerCase() == title?.trim().toLowerCase() &&
        other.limit == limit &&
        _normalizedTags(other.tags).join('|') == _normalizedTags(tags).join('|');
  }

  @override
  int get hashCode => Object.hash(
        currentProductId,
        category?.trim().toLowerCase(),
        title?.trim().toLowerCase(),
        limit,
        _normalizedTags(tags).join('|'),
      );

  static List<String> _normalizedTags(List<String> raw) {
    return raw
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}

final similarProductsProvider =
    FutureProvider.autoDispose.family<List<Product>, SimilarProductsQuery>(
  (ref, query) async {
    ref.watch(storefrontCatalogRevisionProvider);
    return ref.read(productRepositoryProvider).fetchSimilarProducts(
          currentProductId: query.currentProductId,
          category: query.category,
          title: query.title,
          tags: query.tags,
          limit: query.limit,
        );
  },
);

