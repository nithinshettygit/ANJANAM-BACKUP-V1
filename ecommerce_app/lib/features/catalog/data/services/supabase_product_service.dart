import 'dart:math' as math;

import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import '../../domain/entities/product.dart';
import '../../domain/product_sort_option.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';

class SupabaseProductService extends SupabaseServiceBase implements ProductRepository {
  SupabaseProductService(super.client);

  static const Duration _fetchTimeout = Duration(seconds: 45);

  /// Strips characters that would widen ILIKE or break PostgREST `.or()` filters.
  static String _sanitizeSearchToken(String raw) {
    return raw
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(RegExp(r'[,%()]'), '')
        .trim();
  }

  /// At most [maxTokens] non-empty tokens, each capped in length for stable query cost.
  static List<String> _nameSearchTokens(String? nameSearch, {int maxTokens = 8}) {
    if (nameSearch == null) return const [];
    final t = nameSearch.trim();
    if (t.isEmpty) return const [];
    final bounded = t.length > 120 ? t.substring(0, 120) : t;
    return bounded
        .split(RegExp(r'\s+'))
        .map(_sanitizeSearchToken)
        .where((e) => e.isNotEmpty)
        .map((e) => e.length > 40 ? e.substring(0, 40) : e)
        .take(maxTokens)
        .toList();
  }

  static dynamic _applySort(dynamic query, ProductSortOption sort) {
    switch (sort) {
      case ProductSortOption.priceLowToHigh:
        return query
            .order('price', ascending: true)
            .order('id', ascending: true);
      case ProductSortOption.priceHighToLow:
        return query
            .order('price', ascending: false)
            .order('id', ascending: false);
      case ProductSortOption.newest:
        return query
            .order('created_at', ascending: false)
            .order('id', ascending: false);
    }
  }

  static String _pgArrayLiteral(List<String> values) {
    final escaped = values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll(',', r'\,'))
        .toList();
    return '{${escaped.map((e) => '"$e"').join(',')}}';
  }

  @override
  Future<List<Product>> fetchProducts({
    String? category,
    String? nameSearch,
    double? minPrice,
    double? maxPrice,
    bool inStockOnly = false,
    bool popularOnly = false,
    bool recommendedOnly = false,
    bool festivalSpecialOnly = false,
    ProductSortOption sort = ProductSortOption.newest,
    int limit = 20,
    int offset = 0,
  }) async {
    /// [useTagCs]: when true, each token also matches exact `tags` array elements (PostgREST `cs`).
    Future<List<Map<String, dynamic>>> runSelect(
      String columns, {
      bool useTagCs = true,
    }) async {
      dynamic query = client
          .from('products')
          .select(columns)
          .eq('is_active', true);

      if (category != null && category.trim().isNotEmpty) {
        final normalizedCategory = category.trim().toLowerCase();
        query = query.ilike('category', normalizedCategory);
      }

      final tokens = _nameSearchTokens(nameSearch);
      for (final token in tokens) {
        final p = '%$token%';
        if (useTagCs) {
          final tagOnly = token.replaceAll(RegExp(r'[{}]'), '');
          if (tagOnly.isEmpty) {
            query = query.or(
              'title.ilike.$p,category.ilike.$p,description.ilike.$p',
            );
          } else {
            query = query.or(
              'title.ilike.$p,category.ilike.$p,description.ilike.$p,tags.cs.{$tagOnly}',
            );
          }
        } else {
          query = query.or(
            'title.ilike.$p,category.ilike.$p,description.ilike.$p',
          );
        }
      }

      var min = minPrice;
      var max = maxPrice;
      if (min != null && max != null && min > max) {
        final t = min;
        min = max;
        max = t;
      }
      if (min != null) {
        query = query.gte('price', min);
      }
      if (max != null) {
        query = query.lte('price', max);
      }
      if (inStockOnly) {
        query = query.gt('inventory_count', 0);
      }
      if (popularOnly) {
        query = query.eq('is_popular', true);
      }
      if (recommendedOnly) {
        query = query.eq('is_recommended', true);
      }
      if (festivalSpecialOnly) {
        query = query.eq('is_festival_special', true);
      }

      query = _applySort(query, sort);

      final data = await guard(
        () => query.range(offset, offset + limit - 1).timeout(_fetchTimeout),
      );
      return (data as List).cast<Map<String, dynamic>>();
    }

    Future<List<Product>> fetchColumns(String columns) async {
      try {
        final list = await runSelect(columns, useTagCs: true);
        return list.map((e) => ProductModel.fromJson(e).toEntity()).toList();
      } catch (_) {
        final list = await runSelect(columns, useTagCs: false);
        return list.map((e) => ProductModel.fromJson(e).toEntity()).toList();
      }
    }

    // Omit `description` for list queries — large text; details use [fetchProductById].
    // Search still filters on description server-side when [nameSearch] is set.
    try {
      return await fetchColumns(
        'id, title, price, currency, image_urls, category, tags, inventory_count, created_at, display_discount_percent, average_rating, total_reviews, total_written_reviews',
      );
    } catch (_) {
      try {
        return await fetchColumns(
          'id, title, price, currency, image_urls, category, tags, inventory_count, created_at, display_discount_percent',
        );
      } catch (_) {
        return await fetchColumns(
          'id, title, price, currency, image_urls, category, tags, inventory_count, created_at',
        );
      }
    }
  }

  @override
  Future<List<Product>> fetchSimilarProducts({
    required String currentProductId,
    String? category,
    String? title,
    List<String> tags = const [],
    int limit = 8,
  }) async {
    final target = limit.clamp(1, 10);
    final normalizedCategory = category?.trim().toLowerCase();
    final normalizedTags = tags
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final titleTokens = _nameSearchTokens(title, maxTokens: 3);
    final merged = <Product>[];
    final seen = <String>{currentProductId};

    void addUnique(Iterable<Product> items) {
      for (final item in items) {
        if (seen.add(item.id)) {
          merged.add(item);
          if (merged.length >= target) return;
        }
      }
    }

    Future<List<Product>> runDirect({
      String? categoryEquals,
      List<String> overlapTags = const [],
      required int fetchLimit,
    }) async {
      dynamic buildQuery({required bool usePopularity}) {
        dynamic q = client
            .from('products')
            .select(
              'id, title, price, currency, image_urls, category, tags, inventory_count, created_at, display_discount_percent, average_rating, total_reviews, total_written_reviews',
            )
            .eq('is_active', true)
            .neq('id', currentProductId);
        if (categoryEquals != null && categoryEquals.isNotEmpty) {
          q = q.ilike('category', categoryEquals);
        }
        if (overlapTags.isNotEmpty) {
          q = q.filter('tags', 'ov', _pgArrayLiteral(overlapTags));
        }
        if (usePopularity) {
          q = q.order('is_popular', ascending: false);
        }
        return q
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(fetchLimit);
      }

      try {
        final rows = await guard(() => buildQuery(usePopularity: true).timeout(_fetchTimeout));
        return (rows as List)
            .cast<Map<String, dynamic>>()
            .map((e) => ProductModel.fromJson(e).toEntity())
            .toList();
      } catch (_) {
        final rows = await guard(() => buildQuery(usePopularity: false).timeout(_fetchTimeout));
        return (rows as List)
            .cast<Map<String, dynamic>>()
            .map((e) => ProductModel.fromJson(e).toEntity())
            .toList();
      }
    }

    try {
      if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
        final byCategory = await runDirect(
          categoryEquals: normalizedCategory,
          fetchLimit: target * 2,
        );
        addUnique(byCategory);
      }

      if (merged.length < target && normalizedTags.isNotEmpty) {
        final byTags = await runDirect(
          overlapTags: normalizedTags,
          fetchLimit: target * 2,
        );
        addUnique(byTags);
      }
    } catch (_) {
      // Ignore direct-query failures and continue to repository-level fallbacks.
    }

    // Guaranteed simple fallback: same category using standard list query.
    if (merged.length < target &&
        normalizedCategory != null &&
        normalizedCategory.isNotEmpty) {
      try {
        final byCategoryList = await fetchProducts(
          category: normalizedCategory,
          sort: ProductSortOption.newest,
          limit: target * 3,
        );
        addUnique(byCategoryList);
      } catch (_) {}
    }

    // Last fallback: newest active products so the rail is not empty.
    if (merged.length < target && titleTokens.isNotEmpty) {
      try {
        final byName = await fetchProducts(
          nameSearch: titleTokens.join(' '),
          sort: ProductSortOption.newest,
          limit: target * 3,
        );
        addUnique(byName);
      } catch (_) {}
    }

    // Last fallback: newest active products so the rail is not empty.
    if (merged.length < target) {
      try {
        final latest = await fetchProducts(
          sort: ProductSortOption.newest,
          limit: target * 3,
        );
        addUnique(latest);
      } catch (_) {}
    }

    return merged.take(target).toList();
  }

  @override
  Future<List<Product>> fetchProductsByIds(List<String> ids) async {
    final deduped = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      final t = id.trim();
      if (t.isEmpty || !seen.add(t)) continue;
      deduped.add(t);
    }
    if (deduped.isEmpty) return const [];

    Future<List<Product>> runBatch(List<String> batch, String columns) async {
      final data = await guard(
        () => client
            .from('products')
            .select(columns)
            .eq('is_active', true)
            .inFilter('id', batch)
            .timeout(_fetchTimeout),
      );
      return (data as List)
          .cast<Map<String, dynamic>>()
          .map((e) => ProductModel.fromJson(e).toEntity())
          .toList();
    }

    Future<List<Product>> tryBatch(List<String> batch) async {
      try {
        return await runBatch(
          batch,
          'id, title, price, currency, image_urls, category, tags, inventory_count, created_at, display_discount_percent, average_rating, total_reviews, total_written_reviews',
        );
      } catch (_) {
        try {
          return await runBatch(
            batch,
            'id, title, price, currency, image_urls, category, tags, inventory_count, created_at, display_discount_percent',
          );
        } catch (_) {
          return await runBatch(
            batch,
            'id, title, price, currency, image_urls, category, tags, inventory_count, created_at',
          );
        }
      }
    }

    const chunkSize = 80;
    final merged = <Product>[];
    for (var i = 0; i < deduped.length; i += chunkSize) {
      final end = math.min(i + chunkSize, deduped.length);
      merged.addAll(await tryBatch(deduped.sublist(i, end)));
    }
    final byId = {for (final p in merged) p.id: p};
    return deduped.map((id) => byId[id]).whereType<Product>().toList();
  }

  @override
  Future<Product> fetchProductById(String productId) async {
    try {
      final data = await guard(
        () => client
            .from('products')
            .select(
              'id, title, description, price, currency, image_urls, category, tags, inventory_count, created_at, display_discount_percent, average_rating, total_reviews, total_written_reviews',
            )
            .eq('id', productId)
            .eq('is_active', true)
            .single(),
      );
      return ProductModel.fromJson(data).toEntity();
    } catch (_) {
      try {
        final data = await guard(
          () => client
              .from('products')
              .select(
                'id, title, description, price, currency, image_urls, category, tags, inventory_count, created_at, display_discount_percent',
              )
              .eq('id', productId)
              .eq('is_active', true)
              .single(),
        );
        return ProductModel.fromJson(data).toEntity();
      } catch (_) {
        final data = await guard(
          () => client
              .from('products')
              .select(
                'id, title, description, price, currency, image_urls, category, tags, inventory_count, created_at',
              )
              .eq('id', productId)
              .eq('is_active', true)
              .single(),
        );
        return ProductModel.fromJson(data).toEntity();
      }
    }
  }
}

