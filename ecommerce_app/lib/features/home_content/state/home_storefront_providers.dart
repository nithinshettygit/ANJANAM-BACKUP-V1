import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../catalog/state/product_list_providers.dart';
import '../domain/home_hero_banner.dart';
import '../domain/home_top_category_item.dart';

final homeHeroBannersStorefrontProvider =
    FutureProvider.autoDispose<List<HomeHeroBanner>>((ref) async {
  ref.watch(storefrontCatalogRevisionProvider);
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('homepage_hero_banners')
      .select('id, image_url, redirect_type, redirect_value, sort_order')
      .eq('enabled', true)
      .order('sort_order', ascending: true)
      .order('created_at', ascending: true);
  return (data as List)
      .cast<Map<String, dynamic>>()
      .map(HomeHeroBanner.fromJson)
      .where((b) => b.imageUrl.isNotEmpty)
      .toList();
});

final homeTopCategoriesStorefrontProvider =
    FutureProvider.autoDispose<List<HomeTopCategoryItem>>((ref) async {
  ref.watch(storefrontCatalogRevisionProvider);
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('homepage_top_categories')
      .select('id, label, icon_url, category_slug, sort_order')
      .eq('enabled', true)
      .order('sort_order', ascending: true)
      .order('created_at', ascending: true);
  return (data as List)
      .cast<Map<String, dynamic>>()
      .map(HomeTopCategoryItem.fromJson)
      .where((c) => c.label.isNotEmpty && c.categorySlug.isNotEmpty)
      .toList();
});
