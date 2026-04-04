import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/storefront_web_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../features/catalog/domain/entities/product.dart';
import '../../features/catalog/state/product_list_providers.dart';
import '../../features/wishlist/state/wishlist_provider.dart';
import '../utils/storefront_product_navigation.dart';
import 'home_festival_promo_card.dart';
import 'home_layout_metrics.dart';
import 'home_product_discovery_card.dart';
import 'home_recommended_product_card.dart';
import 'web_horizontal_rail_list.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final webDesktop = kIsWeb &&
        StorefrontLayoutScope.layoutWidthOf(context) > StorefrontBreakpoints.tablet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                style: TextStyle(
                  fontSize: HomeLayoutMetrics.homeSectionBadgeFontSize(context),
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
                style: TextStyle(
                  fontSize: HomeLayoutMetrics.homeSectionTitleFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.sectionTitle,
                  height: webDesktop ? 1.28 : 1.2,
                  letterSpacing: webDesktop ? -0.2 : 0,
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
                child: Text(
                  'View all >',
                  style: TextStyle(
                    fontSize: HomeLayoutMetrics.homeSectionViewAllFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        if (webDesktop) ...[
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ],
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
            padding: EdgeInsets.fromLTRB(
              HomeLayoutMetrics.pageHorizontal(context),
              0,
              HomeLayoutMetrics.pageHorizontal(context),
              HomeLayoutMetrics.homeSectionBottomSpacing(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
                SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
                Text(
                  emptyMessage,
                  style: (HomeLayoutMetrics.homeEmptySectionBodyStyle(
                            context,
                            Theme.of(context).textTheme,
                          ) ??
                          Theme.of(context).textTheme.bodyMedium)
                      ?.copyWith(
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
        padding: EdgeInsets.fromLTRB(
          HomeLayoutMetrics.pageHorizontal(context),
          0,
          HomeLayoutMetrics.pageHorizontal(context),
          HomeLayoutMetrics.homeSectionBottomSpacing(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: null,
            ),
            SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
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
    final cardH = HomeLayoutMetrics.popularCardBodyHeight(cardW);
    final rowH = HomeLayoutMetrics.popularRailHeight(context, cardW);

    return Padding(
      padding: EdgeInsets.only(bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
          WebHorizontalRailList(
            height: rowH,
            padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(width: HomeLayoutMetrics.railCardGap(context)),
            itemBuilder: (context, index) {
              final product = products[index];
              return HomeProductDiscoveryCard(
                product: product,
                width: cardW,
                height: cardH,
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
    final cardH = HomeLayoutMetrics.recommendedCardBodyHeight(cardW);
    final rowH = HomeLayoutMetrics.recommendedRailHeight(context, cardW);

    return Padding(
      padding: EdgeInsets.only(bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
          WebHorizontalRailList(
            height: rowH,
            padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(width: HomeLayoutMetrics.railCardGap(context)),
            itemBuilder: (context, index) {
              final product = products[index];
              return HomeRecommendedProductCard(
                product: product,
                width: cardW,
                totalHeight: cardH,
                onOpenDetails: () => navigateToStorefrontProductDetails(
                  context,
                  ref,
                  product.id,
                ),
              );
            },
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
      padding: EdgeInsets.only(bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
          WebHorizontalRailList(
            height: rowH,
            padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(width: HomeLayoutMetrics.railCardGap(context)),
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
    final webDesktop = kIsWeb &&
        StorefrontLayoutScope.layoutWidthOf(context) > StorefrontBreakpoints.tablet;
    final scheme = Theme.of(context).colorScheme;
    final cols = HomeLayoutMetrics.newArrivalsColumnCount(context);
    final preview = products.length > HomeLayoutMetrics.newArrivalsMaxPreview
        ? products.sublist(0, HomeLayoutMetrics.newArrivalsMaxPreview)
        : products;
    final cellW = HomeLayoutMetrics.newArrivalCardWidth(context, cols);
    final rowExtent = HomeLayoutMetrics.newArrivalRowExtentFor(context);
    final gridGap = HomeLayoutMetrics.newArrivalsGridCrossGap(context);
    final gridH = HomeLayoutMetrics.newArrivalsGridHeight(
      itemCount: preview.length,
      crossAxisCount: cols,
      rowExtent: rowExtent,
      mainAxisSpacing: gridGap,
    );

    final grid = SizedBox(
      height: gridH,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisExtent: rowExtent,
          crossAxisSpacing: gridGap,
          mainAxisSpacing: gridGap,
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
    );

    final panelChild = webDesktop
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: grid,
            ),
          )
        : grid;

    return Padding(
      padding: EdgeInsets.only(bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: HomeLayoutMetrics.newArrivalsGridHorizontalPadding(context),
            ),
            child: panelChild,
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
        final cardH = HomeLayoutMetrics.popularCardBodyHeight(cardW);
        final rowH = HomeLayoutMetrics.popularRailHeight(context, cardW);
        return Padding(
          padding: EdgeInsets.only(bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
              WebHorizontalRailList(
                height: rowH,
                padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
                itemCount: 5,
                separatorBuilder: (_, __) => SizedBox(width: HomeLayoutMetrics.railCardGap(context)),
                itemBuilder: (_, __) => _SkeletonCard(width: cardW, height: cardH, base: base),
              ),
            ],
          ),
        );
      case HomeStorefrontProductLayout.recommendedRail:
        final cardW = HomeLayoutMetrics.recommendedCardWidth(context);
        final cardH = HomeLayoutMetrics.recommendedCardBodyHeight(cardW);
        final rowH = HomeLayoutMetrics.recommendedRailHeight(context, cardW);
        return Padding(
          padding: EdgeInsets.only(bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
              WebHorizontalRailList(
                height: rowH,
                padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
                itemCount: 4,
                separatorBuilder: (_, __) => SizedBox(width: HomeLayoutMetrics.railCardGap(context)),
                itemBuilder: (_, __) => _SkeletonCard(width: cardW, height: cardH, base: base),
              ),
            ],
          ),
        );
      case HomeStorefrontProductLayout.festivalBannerRail:
        final cardW = HomeLayoutMetrics.festivalCardWidth(context);
        final cardH = HomeLayoutMetrics.festivalCardHeight(context);
        final rowH = HomeLayoutMetrics.festivalRailHeight(context);
        return Padding(
          padding: EdgeInsets.only(bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
              WebHorizontalRailList(
                height: rowH,
                padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
                itemCount: 3,
                separatorBuilder: (_, __) => SizedBox(width: HomeLayoutMetrics.railCardGap(context)),
                itemBuilder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: cardW,
                    height: cardH,
                    color: base,
                  ),
                ),
              ),
            ],
          ),
        );
      case HomeStorefrontProductLayout.newArrivalsGrid:
        final webDesktop = kIsWeb &&
            StorefrontLayoutScope.layoutWidthOf(context) > StorefrontBreakpoints.tablet;
        final scheme = Theme.of(context).colorScheme;
        final cols = HomeLayoutMetrics.newArrivalsColumnCount(context);
        final cellW = HomeLayoutMetrics.newArrivalCardWidth(context, cols);
        final rowExtent = HomeLayoutMetrics.newArrivalRowExtentFor(context);
        final gridGap = HomeLayoutMetrics.newArrivalsGridCrossGap(context);
        final gridH = HomeLayoutMetrics.newArrivalsGridHeight(
          itemCount: cols * 2,
          crossAxisCount: cols,
          rowExtent: rowExtent,
          mainAxisSpacing: gridGap,
        );
        final grid = SizedBox(
          height: gridH,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: rowExtent,
              crossAxisSpacing: gridGap,
              mainAxisSpacing: gridGap,
            ),
            itemCount: cols * 2,
            itemBuilder: (_, __) => _SkeletonCard(width: cellW, height: rowExtent, base: base),
          ),
        );
        final panelChild = webDesktop
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: grid,
                ),
              )
            : grid;
        return Padding(
          padding: EdgeInsets.only(bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: HomeLayoutMetrics.pageHorizontal(context)),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: HomeLayoutMetrics.newArrivalsGridHorizontalPadding(context),
                ),
                child: panelChild,
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
