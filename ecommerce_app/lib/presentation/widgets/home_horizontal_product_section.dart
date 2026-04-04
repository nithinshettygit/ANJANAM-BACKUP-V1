import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/catalog/domain/entities/product.dart';
import '../../features/catalog/state/product_list_providers.dart';
import '../../features/wishlist/state/wishlist_provider.dart';
import '../utils/storefront_product_navigation.dart';
import 'home_festival_promo_card.dart';
import 'home_layout_metrics.dart';
import 'home_product_discovery_card.dart';
import 'home_recommended_product_card.dart';

/// Layout variants for mixed home merchandising.
enum HomeStorefrontProductLayout {
  popularRail,
  recommendedRail,
  festivalBannerRail,
  newArrivalsGrid,
}

class HomeStorefrontSectionHeader extends StatelessWidget {
  const HomeStorefrontSectionHeader({
    super.key,
    required this.title,
    required this.badgeLabel,
    this.onViewAll,
  });

  final String title;
  final String badgeLabel;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.brandSaffron.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badgeLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandSaffronDeep,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.sectionTitle,
              height: 1.2,
            ),
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandSaffron,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'View all >',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Product-driven home section with rail or grid layout.
class HomeHorizontalProductSection extends ConsumerWidget {
  const HomeHorizontalProductSection({
    super.key,
    required this.title,
    required this.query,
    required this.layout,
    required this.sectionBadge,
    this.onViewAll,
    this.emptyMessage = 'Nothing here yet — check back soon.',
  });

  final String title;
  final ProductListQuery query;
  final HomeStorefrontProductLayout layout;
  final String sectionBadge;
  final VoidCallback? onViewAll;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productListProvider(query));
    final wishlist = ref.watch(wishlistProvider);

    return async.when(
      data: (products) {
        if (products.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
                const SizedBox(height: 8),
                Text(
                  emptyMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }
        switch (layout) {
          case HomeStorefrontProductLayout.popularRail:
            return _PopularRail(
              title: title,
              sectionBadge: sectionBadge,
              onViewAll: onViewAll,
              products: products,
              wishlist: wishlist,
              ref: ref,
            );
          case HomeStorefrontProductLayout.recommendedRail:
            return _RecommendedRail(
              title: title,
              sectionBadge: sectionBadge,
              onViewAll: onViewAll,
              products: products,
              ref: ref,
            );
          case HomeStorefrontProductLayout.festivalBannerRail:
            return _FestivalRail(
              title: title,
              sectionBadge: sectionBadge,
              onViewAll: onViewAll,
              products: products,
              ref: ref,
            );
          case HomeStorefrontProductLayout.newArrivalsGrid:
            return _NewArrivalsGrid(
              title: title,
              sectionBadge: sectionBadge,
              onViewAll: onViewAll,
              products: products,
              wishlist: wishlist,
              ref: ref,
            );
        }
      },
      loading: () => _LoadingBlock(
            layout: layout,
            title: title,
            sectionBadge: sectionBadge,
          ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: null,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load this section.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularRail extends StatelessWidget {
  const _PopularRail({
    required this.title,
    required this.sectionBadge,
    required this.onViewAll,
    required this.products,
    required this.wishlist,
    required this.ref,
  });

  final String title;
  final String sectionBadge;
  final VoidCallback? onViewAll;
  final List<Product> products;
  final Set<String> wishlist;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cardW = HomeLayoutMetrics.popularCardWidth(context);
    final rowH = HomeLayoutMetrics.popularRailHeight(cardW);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          SizedBox(
            height: rowH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.cardGap),
              itemBuilder: (context, index) {
                final product = products[index];
                return HomeProductDiscoveryCard(
                  product: product,
                  width: cardW,
                  height: rowH,
                  isWishlisted: wishlist.contains(product.id),
                  onToggleWishlist: () {
                    ref.read(wishlistControllerProvider.notifier).toggle(product.id);
                  },
                  onTap: () => navigateToStorefrontProductDetails(
                    context,
                    ref,
                    product.id,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedRail extends StatelessWidget {
  const _RecommendedRail({
    required this.title,
    required this.sectionBadge,
    required this.onViewAll,
    required this.products,
    required this.ref,
  });

  final String title;
  final String sectionBadge;
  final VoidCallback? onViewAll;
  final List<Product> products;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cardW = HomeLayoutMetrics.recommendedCardWidth(context);
    final rowH = HomeLayoutMetrics.recommendedRailHeight(cardW);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          SizedBox(
            height: rowH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.cardGap),
              itemBuilder: (context, index) {
                final product = products[index];
                return HomeRecommendedProductCard(
                  product: product,
                  width: cardW,
                  totalHeight: rowH,
                  onOpenDetails: () => navigateToStorefrontProductDetails(
                    context,
                    ref,
                    product.id,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FestivalRail extends StatelessWidget {
  const _FestivalRail({
    required this.title,
    required this.sectionBadge,
    required this.onViewAll,
    required this.products,
    required this.ref,
  });

  final String title;
  final String sectionBadge;
  final VoidCallback? onViewAll;
  final List<Product> products;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cardW = HomeLayoutMetrics.festivalCardWidth(context);
    final cardH = HomeLayoutMetrics.festivalCardHeight(context);
    final rowH = HomeLayoutMetrics.festivalRailHeight(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          SizedBox(
            height: rowH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.cardGap),
              itemBuilder: (context, index) {
                final product = products[index];
                void open() => navigateToStorefrontProductDetails(
                      context,
                      ref,
                      product.id,
                    );
                return HomeFestivalPromoCard(
                  product: product,
                  width: cardW,
                  height: cardH,
                  onExplore: open,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NewArrivalsGrid extends StatelessWidget {
  const _NewArrivalsGrid({
    required this.title,
    required this.sectionBadge,
    required this.onViewAll,
    required this.products,
    required this.wishlist,
    required this.ref,
  });

  final String title;
  final String sectionBadge;
  final VoidCallback? onViewAll;
  final List<Product> products;
  final Set<String> wishlist;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cols = HomeLayoutMetrics.newArrivalsColumnCount(context);
    final preview = products.length > HomeLayoutMetrics.newArrivalsMaxPreview
        ? products.sublist(0, HomeLayoutMetrics.newArrivalsMaxPreview)
        : products;
    final cellW = HomeLayoutMetrics.newArrivalCardWidth(context, cols);
    const rowExtent = HomeLayoutMetrics.newArrivalRowExtent;
    final gridH = HomeLayoutMetrics.newArrivalsGridHeight(
      itemCount: preview.length,
      crossAxisCount: cols,
      rowExtent: rowExtent,
      mainAxisSpacing: AppSpacing.cardGap,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: SizedBox(
              height: gridH,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: rowExtent,
                  crossAxisSpacing: AppSpacing.cardGap,
                  mainAxisSpacing: AppSpacing.cardGap,
                ),
                itemCount: preview.length,
                itemBuilder: (context, index) {
                  final product = preview[index];
                  return HomeProductDiscoveryCard(
                    product: product,
                    width: cellW,
                    height: rowExtent,
                    isWishlisted: wishlist.contains(product.id),
                    onToggleWishlist: () {
                      ref.read(wishlistControllerProvider.notifier).toggle(product.id);
                    },
                    onTap: () => navigateToStorefrontProductDetails(
                      context,
                      ref,
                      product.id,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({
    required this.layout,
    required this.title,
    required this.sectionBadge,
  });

  final HomeStorefrontProductLayout layout;
  final String title;
  final String sectionBadge;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);

    switch (layout) {
      case HomeStorefrontProductLayout.popularRail:
        final cardW = HomeLayoutMetrics.popularCardWidth(context);
        final rowH = HomeLayoutMetrics.popularRailHeight(cardW);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              SizedBox(
                height: rowH,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.cardGap),
                  itemBuilder: (_, __) => _SkeletonCard(width: cardW, height: rowH, base: base),
                ),
              ),
            ],
          ),
        );
      case HomeStorefrontProductLayout.recommendedRail:
        final cardW = HomeLayoutMetrics.recommendedCardWidth(context);
        final rowH = HomeLayoutMetrics.recommendedRailHeight(cardW);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              SizedBox(
                height: rowH,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.cardGap),
                  itemBuilder: (_, __) => _SkeletonCard(width: cardW, height: rowH, base: base),
                ),
              ),
            ],
          ),
        );
      case HomeStorefrontProductLayout.festivalBannerRail:
        final cardW = HomeLayoutMetrics.festivalCardWidth(context);
        final cardH = HomeLayoutMetrics.festivalCardHeight(context);
        final rowH = HomeLayoutMetrics.festivalRailHeight(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              SizedBox(
                height: rowH,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.cardGap),
                  itemBuilder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: cardW,
                      height: cardH,
                      color: base,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case HomeStorefrontProductLayout.newArrivalsGrid:
        final cols = HomeLayoutMetrics.newArrivalsColumnCount(context);
        final cellW = HomeLayoutMetrics.newArrivalCardWidth(context, cols);
        const rowExtent = HomeLayoutMetrics.newArrivalRowExtent;
        final gridH = HomeLayoutMetrics.newArrivalsGridHeight(
          itemCount: cols * 2,
          crossAxisCount: cols,
          rowExtent: rowExtent,
          mainAxisSpacing: AppSpacing.cardGap,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SizedBox(
                  height: gridH,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: rowExtent,
                      crossAxisSpacing: AppSpacing.cardGap,
                      mainAxisSpacing: AppSpacing.cardGap,
                    ),
                    itemCount: cols * 2,
                    itemBuilder: (_, __) => _SkeletonCard(width: cellW, height: rowExtent, base: base),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.width,
    required this.height,
    required this.base,
  });

  final double width;
  final double height;
  final Color base;

  @override
  Widget build(BuildContext context) {
    final img = (width * 0.92).clamp(72.0, width);
    return SizedBox(
      width: width,
      height: height,
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: img,
              color: base,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: width * 0.85,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 14,
                      width: width * 0.45,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
