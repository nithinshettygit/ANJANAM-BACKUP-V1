import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';

import '../models/product_suggestion.dart';

class SupabaseSearchSuggestionsService extends SupabaseServiceBase {
  SupabaseSearchSuggestionsService(super.client);

  static const int kMaxSuggestions = 12;
  static const int kMinQueryLength = 2;

  /// Safe input for client-side fallback `ilike` (strip wildcards).
  static String sanitizeIlikePrefix(String raw) {
    return raw
        .trim()
        .replaceAll('\\', '')
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(RegExp(r'[,%()]'), '');
  }

  /// Rich suggestions via RPC (title, category, description, tags); falls back to title prefix if RPC fails.
  Future<List<ProductSuggestion>> fetchSearchSuggestions(String query) async {
    return guard(() async {
      final q = query.trim();
      if (q.length < kMinQueryLength) return <ProductSuggestion>[];

      try {
        final raw = await client.rpc(
          'storefront_search_suggestions',
          params: <String, dynamic>{
            'p_query': q,
            'p_limit': kMaxSuggestions,
          },
        );
        final parsed = _parseRpcSuggestions(raw);
        if (parsed != null) return parsed;
      } catch (_) {
        // Migration not applied or RPC unavailable — use legacy query.
      }

      return _fetchLegacyTitlePrefix(q);
    });
  }

  List<ProductSuggestion>? _parseRpcSuggestions(dynamic raw) {
    if (raw == null) return <ProductSuggestion>[];
    if (raw is! List) return null;
    return raw
        .map((e) {
          if (e is! Map) return null;
          return ProductSuggestion.fromJson(Map<String, dynamic>.from(e));
        })
        .whereType<ProductSuggestion>()
        .where((s) => s.id.isNotEmpty && s.name.isNotEmpty)
        .toList();
  }

  Future<List<ProductSuggestion>> _fetchLegacyTitlePrefix(String q) async {
    final safe = sanitizeIlikePrefix(q);
    if (safe.length < kMinQueryLength) return <ProductSuggestion>[];

    final pattern = '$safe%';
    final rows = await client
        .from('products')
        .select('id, title, category')
        .eq('is_active', true)
        .ilike('title', pattern)
        .order('title', ascending: true)
        .limit(kMaxSuggestions);

    final list = rows as List<dynamic>? ?? const [];
    return list
        .map(
          (e) => ProductSuggestion.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
}
