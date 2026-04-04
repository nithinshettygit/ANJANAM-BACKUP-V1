import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/entities/product.dart';
import '../../catalog/state/product_list_providers.dart';
import 'wishlist_provider.dart';

/// Wishlisted products only (no full-catalog fetch). Refreshes when catalog revision bumps.
final wishlistProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(storefrontCatalogRevisionProvider);
  final ids = ref.watch(wishlistProvider);
  if (ids.isEmpty) return const [];
  final repo = ref.read(productRepositoryProvider);
  return repo.fetchProductsByIds(ids.toList());
});
