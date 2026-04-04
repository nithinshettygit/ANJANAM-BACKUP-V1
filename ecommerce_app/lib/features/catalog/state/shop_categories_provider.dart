import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../presentation/utils/storefront_category_slug.dart';
import '../domain/shop_category.dart';
import 'product_list_providers.dart';

/// PostgREST / Supabase often caps each response (~1000 rows). Page through all rows.
const int _kShopCategoryPageSize = 1000;

/// All active [categories] rows (paged), ordered like admin.
Future<List<Map<String, dynamic>>> _fetchAllActiveCategoryRows(SupabaseClient client) async {
  final out = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final chunk = await client
        .from('categories')
        .select('id, name, slug, image_url, display_order')
        .eq('is_active', true)
        .order('display_order', ascending: true)
        .order('name', ascending: true)
        .range(offset, offset + _kShopCategoryPageSize - 1);
    final list = (chunk as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) break;
    out.addAll(list);
    if (list.length < _kShopCategoryPageSize) break;
    offset += _kShopCategoryPageSize;
  }
  return out;
}

/// Per-normalized-key counts from **all** active products (paged).
Future<Map<String, int>> _productCountsByCategorySlug(SupabaseClient client) async {
  final m = <String, int>{};
  var offset = 0;
  while (true) {
    try {
      final rows = await client
          .from('products')
          .select('category')
          .eq('is_active', true)
          .range(offset, offset + _kShopCategoryPageSize - 1);
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) break;
      for (final row in list) {
        final k = normalizeProductCategoryKey(row['category']?.toString());
        if (k.isEmpty) continue;
        m[k] = (m[k] ?? 0) + 1;
      }
      if (list.length < _kShopCategoryPageSize) break;
      offset += _kShopCategoryPageSize;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Shop categories: product category page at offset $offset failed: $e\n$st');
      }
      break;
    }
  }
  return m;
}

/// Shop grid: every **active** row in [categories], plus any [products.category]
/// values (active products) not already represented — all from Supabase only.
Future<List<ShopCategory>> fetchShopCategoriesFromBackend(SupabaseClient client) async {
  final counts = await _productCountsByCategorySlug(client);

  List<Map<String, dynamic>> rawRows = [];
  try {
    rawRows = await _fetchAllActiveCategoryRows(client);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint(
        'Shop categories: categories table query failed (showing product-only categories): $e\n$st',
      );
    }
    rawRows = [];
  }

  final base = rawRows
      .map(ShopCategory.fromCategoriesTableJson)
      .where((c) => c.slug.isNotEmpty)
      .toList();

  final fromTable = base
      .map(
        (c) => ShopCategory(
          id: c.id,
          name: c.name,
          slug: c.slug,
          imageUrl: c.imageUrl,
          displayOrder: c.displayOrder,
          productCount: counts[normalizeProductCategoryKey(c.slug)] ?? 0,
        ),
      )
      .toList();

  final tableKeys = {
    for (final c in fromTable) normalizeProductCategoryKey(c.slug),
  };

  final extras = <ShopCategory>[];
  for (final e in counts.entries) {
    final k = e.key;
    if (k.isEmpty) continue;
    if (tableKeys.contains(k)) continue;
    if (normalizeStorefrontCategorySlug(k) == null) continue;
    extras.add(
      ShopCategory(
        id: 'product-category|$k',
        name: derivedDisplayNameFromSlug(k),
        slug: k,
        displayOrder: 999999,
        productCount: e.value,
      ),
    );
  }
  extras.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

  return [...fromTable, ...extras];
}

/// Categories shown on the Shop tab — always loaded from Supabase [categories] + live counts.
final shopCategoriesStorefrontProvider =
    FutureProvider.autoDispose<List<ShopCategory>>((ref) async {
  ref.watch(storefrontCatalogRevisionProvider);
  final client = ref.watch(supabaseClientProvider);
  try {
    return await fetchShopCategoriesFromBackend(client);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Shop categories: fetchShopCategoriesFromBackend failed: $e\n$st');
    }
    return const [];
  }
});

/// Catalog filter: same combined Supabase-backed list as the Shop tab.
final catalogFilterCategoriesProvider =
    FutureProvider.autoDispose<List<ShopCategory>>((ref) async {
  ref.watch(storefrontCatalogRevisionProvider);
  final client = ref.watch(supabaseClientProvider);
  try {
    return await fetchShopCategoriesFromBackend(client);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Catalog filter categories failed: $e\n$st');
    }
    return const [];
  }
});
