import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/home_content/domain/home_hero_banner.dart';
import '../pages/catalog_page.dart';
import 'storefront_product_navigation.dart';

String _catalogTitleForSlug(String slug) {
  final t = slug.trim();
  if (t.isEmpty) return 'Products';
  if (t.length == 1) return t.toUpperCase();
  return '${t[0].toUpperCase()}${t.substring(1)}';
}

Future<void> openHomeBannerTarget(
  BuildContext context,
  WidgetRef ref,
  HomeHeroBanner banner,
) async {
  Future<void> openExternal(String rawUrl) async {
    var value = rawUrl.trim();
    if (value.isEmpty) return;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open external link.')),
      );
    }
  }

  switch (banner.redirectType) {
    case HomeBannerRedirectType.category:
      final slug = banner.redirectValue.trim().toLowerCase();
      if (slug.isEmpty) return;
      if (!context.mounted) return;
      await Navigator.of(context).pushNamed(
        '/products',
        arguments: {
          'category': slug,
          'title': _catalogTitleForSlug(slug),
        },
      );
      return;
    case HomeBannerRedirectType.product:
      final id = banner.redirectValue.trim();
      if (id.isEmpty) return;
      await navigateToStorefrontProductDetails(context, ref, id);
      return;
    case HomeBannerRedirectType.collection:
      final key = banner.redirectValue.trim().toLowerCase();
      if (!context.mounted || key.isEmpty) return;
      switch (key) {
        case 'popular':
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const CatalogPage(
                title: 'Popular Products',
                popularOnly: true,
              ),
            ),
          );
          return;
        case 'recommended':
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const CatalogPage(
                title: 'Recommended For You',
                recommendedOnly: true,
              ),
            ),
          );
          return;
        case 'festival':
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const CatalogPage(
                title: 'Festival Specials',
                festivalSpecialOnly: true,
              ),
            ),
          );
          return;
        case 'new_arrivals':
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const CatalogPage(
                title: 'New Arrivals',
              ),
            ),
          );
          return;
        default:
          await Navigator.of(context).pushNamed('/catalog');
          return;
      }
    case HomeBannerRedirectType.externalLink:
      await openExternal(banner.redirectValue);
      return;
    case HomeBannerRedirectType.path:
      final path = banner.redirectValue.trim();
      if (path.isEmpty) return;
      // Legacy compatibility with older DB values.
      if (path.startsWith('/')) {
        if (!context.mounted) return;
        await Navigator.of(context).pushNamed(path);
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        await openExternal(path);
      }
      return;
    case HomeBannerRedirectType.none:
      return;
  }
}
