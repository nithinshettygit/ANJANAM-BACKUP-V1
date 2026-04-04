import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import '../data/services/supabase_product_service.dart';
import '../domain/entities/product.dart';
import '../domain/product_sort_option.dart';
import '../domain/repositories/product_repository.dart';

/// Bump this (e.g. on pull-to-refresh or app resume) so every [productListProvider]
/// and [productDetailsProvider] refetches — picks up admin stock/catalog changes.
///
/// Riverpod 3: [StateProvider] was removed; use [NotifierProvider] + [Notifier].
final storefrontCatalogRevisionProvider =
    NotifierProvider<StorefrontCatalogRevisionNotifier, int>(
  StorefrontCatalogRevisionNotifier.new,
);

class StorefrontCatalogRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Invalidates all storefront product list/detail fetches that watch this revision.
  void bump() => state = state + 1;
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => SupabaseProductService(ref.watch(supabaseClientProvider)),
);

class ProductListQuery {
  final String? category;
  /// Raw search string; matched case-insensitively with partial AND tokens on title.
  final String? nameSearch;
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final bool popularOnly;
  final bool recommendedOnly;
  final bool festivalSpecialOnly;
  final ProductSortOption sort;
  final int limit;
  final int offset;

  const ProductListQuery({
    this.category,
    this.nameSearch,
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.popularOnly = false,
    this.recommendedOnly = false,
    this.festivalSpecialOnly = false,
    this.sort = ProductSortOption.newest,
    this.limit = 20,
    this.offset = 0,
  });

  String? get _normalizedCategory {
    final value = category?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String? get _normalizedNameSearch {
    final value = nameSearch?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductListQuery &&
        other._normalizedCategory == _normalizedCategory &&
        other._normalizedNameSearch == _normalizedNameSearch &&
        other.minPrice == minPrice &&
        other.maxPrice == maxPrice &&
        other.inStockOnly == inStockOnly &&
        other.popularOnly == popularOnly &&
        other.recommendedOnly == recommendedOnly &&
        other.festivalSpecialOnly == festivalSpecialOnly &&
        other.sort == sort &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(
        _normalizedCategory,
        _normalizedNameSearch,
        minPrice,
        maxPrice,
        inStockOnly,
        popularOnly,
        recommendedOnly,
        festivalSpecialOnly,
        sort,
        limit,
        offset,
      );
}

final productListProvider =
    FutureProvider.autoDispose.family<List<Product>, ProductListQuery>(
  (ref, query) async {
    // Riverpod 3 defaults to auto-dispose; without this, brief unsubscribe (e.g. route
    // transitions) can drop the in-flight request so the UI stays on loading forever.
    // Search queries stay disposable so typed queries do not accumulate in memory.
    final searching = (query.nameSearch ?? '').trim().isNotEmpty;
    if (!searching) {
      ref.keepAlive();
    }

    ref.watch(storefrontCatalogRevisionProvider);
    final repo = ref.read(productRepositoryProvider);
    return repo.fetchProducts(
      category: query.category,
      nameSearch: query.nameSearch,
      minPrice: query.minPrice,
      maxPrice: query.maxPrice,
      inStockOnly: query.inStockOnly,
      popularOnly: query.popularOnly,
      recommendedOnly: query.recommendedOnly,
      festivalSpecialOnly: query.festivalSpecialOnly,
      sort: query.sort,
      limit: query.limit,
      offset: query.offset,
    );
  },
);

