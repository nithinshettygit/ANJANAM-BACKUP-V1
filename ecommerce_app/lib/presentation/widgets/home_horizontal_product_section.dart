import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/storefront_web_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/wishlist_heart_sizes.dart';
import '../../features/catalog/domain/entities/product.dart';
import '../../features/catalog/state/product_list_providers.dart';
import '../../features/wishlist/state/wishlist_provider.dart';
import '../utils/storefront_product_navigation.dart';
import 'home_festival_promo_card.dart';
import 'home_layout_metrics.dart';
import 'home_product_discovery_card.dart';
import 'home_recommended_product_card.dart';
import 'web_horizontal_rail_list.dart';
import '../../l10n/app_localizations.dart';

/// Layout variants for mixed home merchandising.
enum HomeStorefrontProductLayout {
  popularRail,
  recommendedRail,
  festivalBannerRail,
  newArrivalsGrid,
}

class _ShelfColors {
  const _ShelfColors({
    required this.fill,
    required this.border,
    required this.shadowTint,
  });
  final Color fill;
  final Color border;
  /// Warm glow under the shelf, keyed to section mood.
  final Color shadowTint;
}

_ShelfColors _homeShelfColors(HomeStorefrontProductLayout layout) {
  switch (layout) {
    case HomeStorefrontProductLayout.popularRail:
      return const _ShelfColors(
        fill: AppColors.homeShelfPopularFill,
        border: AppColors.homeShelfPopularBorder,
        shadowTint: AppColors.brandSaffron,
      );
    case HomeStorefrontProductLayout.recommendedRail:
      return const _ShelfColors(
        fill: AppColors.homeShelfRecommendedFill,
        border: AppColors.homeShelfRecommendedBorder,
        shadowTint: AppColors.homeShelfRecommendedShadowTint,
      );
    case HomeStorefrontProductLayout.festivalBannerRail:
      return const _ShelfColors(
        fill: AppColors.homeShelfFestivalFill,
        border: AppColors.homeShelfFestivalBorder,
        shadowTint: AppColors.homeShelfFestivalShadowTint,
      );
    case HomeStorefrontProductLayout.newArrivalsGrid:
      return const _ShelfColors(
        fill: AppColors.homeShelfNewArrivalsFill,
        border: AppColors.homeShelfNewArrivalsBorder,
        shadowTint: AppColors.forestGreen,
      );
  }
}

BorderRadius _homeShelfRadius(BuildContext context) {
  final wide = kIsWeb &&
      StorefrontLayoutScope.layoutWidthOf(context) > StorefrontBreakpoints.tablet;
  return BorderRadius.circular(wide ? 18 : 14);
}

/// Flipkart-style tinted block: header + horizontal rail / grid inside a soft panel.
class _HomeSectionShelf extends StatelessWidget {
  const _HomeSectionShelf({
    required this.layout,
    required this.bottomSpacing,
    required this.child,
  });

  final HomeStorefrontProductLayout layout;
  final double bottomSpacing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pageH = HomeLayoutMetrics.pageHorizontal(context);
    final colors = _homeShelfColors(layout);
    final radius = _homeShelfRadius(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pageH, 0, pageH, bottomSpacing),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: radius,
          border: Border.all(
            width: 1.25,
            color: colors.border.withValues(alpha: 0.88),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadowTint.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: child,
        ),
      ),
    );
  }
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
                  fontWeight: FontWeight.w800,
                  color: AppColors.sectionTitle,
                  height: webDesktop ? 1.25 : 1.2,
                  letterSpacing: webDesktop ? -0.35 : -0.3,
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
                  AppLocalizations.of(context).viewAll,
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
          final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
          return _HomeSectionShelf(
            layout: layout,
            bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
            child: Padding(
              padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, inner + 2),
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
              wishlist: wishlist,
              ref: ref,
            );
          case HomeStorefrontProductLayout.festivalBannerRail:
            return _FestivalRail(
              title: title,
              sectionBadge: sectionBadge,
              onViewAll: onViewAll,
              products: products,
              wishlist: wishlist,
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
      error: (e, _) {
        final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
        return _HomeSectionShelf(
          layout: layout,
          bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
          child: Padding(
            padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, inner + 2),
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
      },
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
    final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
    final gap = HomeLayoutMetrics.popularRailCardGap(context);
    final snapInset = HomeLayoutMetrics.popularRailSnapEndInset(gap);
    final snapFrac = !kIsWeb
        ? HomeLayoutMetrics.homeRailSnapViewportFraction(
            context,
            cardW,
            gap,
            nextCardPeekPx: snapInset,
          )
        : null;

    return _HomeSectionShelf(
      layout: HomeStorefrontProductLayout.popularRail,
      bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, 0),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
          WebHorizontalRailList(
            height: rowH,
            padding: EdgeInsets.fromLTRB(inner, 0, inner, inner + 2),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(width: gap),
            snapViewportFraction: snapFrac,
            snapPageTrailingPadding: !kIsWeb ? snapInset : 0,
            snapScrollPhysics: !kIsWeb
                ? const PopularRailPageScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  )
                : null,
            itemBuilder: (context, index) {
              final product = products[index];
              final wl = WishlistHeartSizes.homeShelfWishlistForImageWidth(cardW);
              return HomeProductDiscoveryCard(
                product: product,
                width: cardW,
                height: cardH,
                wishlistHeartSize: wl.heartSize,
                wishlistChipExtent: wl.chipExtent,
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
    final cardW = HomeLayoutMetrics.recommendedCardWidth(context);
    final cardH = HomeLayoutMetrics.recommendedCardBodyHeight(cardW);
    final rowH = HomeLayoutMetrics.recommendedRailHeight(context, cardW);
    final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
    final gap = HomeLayoutMetrics.railCardGap(context);

    return _HomeSectionShelf(
      layout: HomeStorefrontProductLayout.recommendedRail,
      bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, 0),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
          WebHorizontalRailList(
            height: rowH,
            padding: EdgeInsets.fromLTRB(inner, 0, inner, inner + 2),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(width: gap),
            itemBuilder: (context, index) {
              final product = products[index];
              final wl = WishlistHeartSizes.homeShelfWishlistForImageWidth(cardW);
              return HomeRecommendedProductCard(
                product: product,
                width: cardW,
                totalHeight: cardH,
                wishlistHeartSize: wl.heartSize,
                wishlistChipExtent: wl.chipExtent,
                onOpenDetails: () => navigateToStorefrontProductDetails(
                  context,
                  ref,
                  product.id,
                ),
                isWishlisted: wishlist.contains(product.id),
                onToggleWishlist: () {
                  ref.read(wishlistControllerProvider.notifier).toggle(product.id);
                },
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
    final cardW = HomeLayoutMetrics.festivalCardWidth(context);
    final cardH = HomeLayoutMetrics.festivalCardHeight(context);
    final rowH = HomeLayoutMetrics.festivalRailHeight(context);
    final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
    final gap = HomeLayoutMetrics.festivalRailCardGap(context);
    final snapFrac = !kIsWeb
        ? HomeLayoutMetrics.homeRailSnapViewportFraction(context, cardW, gap)
        : null;

    return _HomeSectionShelf(
      layout: HomeStorefrontProductLayout.festivalBannerRail,
      bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, 0),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
          WebHorizontalRailList(
            height: rowH,
            padding: EdgeInsets.fromLTRB(inner, 0, inner, inner + 2),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(width: gap),
            snapViewportFraction: snapFrac,
            itemBuilder: (context, index) {
              final product = products[index];
              void open() => navigateToStorefrontProductDetails(
                    context,
                    ref,
                    product.id,
                  );
              final wl = WishlistHeartSizes.homeShelfWishlistForImageWidth(cardW);
              return HomeFestivalPromoCard(
                product: product,
                width: cardW,
                height: cardH,
                wishlistHeartSize: wl.heartSize,
                wishlistChipExtent: wl.chipExtent,
                onExplore: open,
                isWishlisted: wishlist.contains(product.id),
                onToggleWishlist: () {
                  ref.read(wishlistControllerProvider.notifier).toggle(product.id);
                },
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
    final cols = HomeLayoutMetrics.newArrivalsColumnCount(context);
    final preview = products.length > HomeLayoutMetrics.newArrivalsMaxPreview
        ? products.sublist(0, HomeLayoutMetrics.newArrivalsMaxPreview)
        : products;
    final cellW = HomeLayoutMetrics.newArrivalCardWidthInShelf(context, cols);
    final rowExtent = HomeLayoutMetrics.newArrivalRowExtentFor(context);
    final gridGap = HomeLayoutMetrics.newArrivalsGridCrossGap(context);
    final gridH = HomeLayoutMetrics.newArrivalsGridHeight(
      itemCount: preview.length,
      crossAxisCount: cols,
      rowExtent: rowExtent,
      mainAxisSpacing: gridGap,
    );
    final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);

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
          final wl = WishlistHeartSizes.homeShelfWishlistForImageWidth(cellW);
          return HomeProductDiscoveryCard(
            product: product,
            width: cellW,
            height: rowExtent,
            wishlistHeartSize: wl.heartSize,
            wishlistChipExtent: wl.chipExtent,
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

    return _HomeSectionShelf(
      layout: HomeStorefrontProductLayout.newArrivalsGrid,
      bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, 0),
            child: HomeStorefrontSectionHeader(
              title: title,
              badgeLabel: sectionBadge,
              onViewAll: onViewAll,
            ),
          ),
          SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
          Padding(
            padding: EdgeInsets.fromLTRB(inner, 0, inner, inner + 2),
            child: grid,
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
        final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
        final gap = HomeLayoutMetrics.popularRailCardGap(context);
        final snapInset = HomeLayoutMetrics.popularRailSnapEndInset(gap);
        final snapFrac = !kIsWeb
            ? HomeLayoutMetrics.homeRailSnapViewportFraction(
                context,
                cardW,
                gap,
                nextCardPeekPx: snapInset,
              )
            : null;
        return _HomeSectionShelf(
          layout: layout,
          bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, 0),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
              WebHorizontalRailList(
                height: rowH,
                padding: EdgeInsets.fromLTRB(inner, 0, inner, inner + 2),
                itemCount: 5,
                separatorBuilder: (_, __) => SizedBox(width: gap),
                snapViewportFraction: snapFrac,
                snapPageTrailingPadding: !kIsWeb ? snapInset : 0,
                snapScrollPhysics: !kIsWeb
                    ? const PopularRailPageScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      )
                    : null,
                itemBuilder: (_, __) => _SkeletonCard(width: cardW, height: cardH, base: base),
              ),
            ],
          ),
        );
      case HomeStorefrontProductLayout.recommendedRail:
        final cardW = HomeLayoutMetrics.recommendedCardWidth(context);
        final cardH = HomeLayoutMetrics.recommendedCardBodyHeight(cardW);
        final rowH = HomeLayoutMetrics.recommendedRailHeight(context, cardW);
        final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
        final gap = HomeLayoutMetrics.railCardGap(context);
        return _HomeSectionShelf(
          layout: layout,
          bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, 0),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
              WebHorizontalRailList(
                height: rowH,
                padding: EdgeInsets.fromLTRB(inner, 0, inner, inner + 2),
                itemCount: 4,
                separatorBuilder: (_, __) => SizedBox(width: gap),
                itemBuilder: (_, __) => _SkeletonCard(width: cardW, height: cardH, base: base),
              ),
            ],
          ),
        );
      case HomeStorefrontProductLayout.festivalBannerRail:
        final cardW = HomeLayoutMetrics.festivalCardWidth(context);
        final cardH = HomeLayoutMetrics.festivalCardHeight(context);
        final rowH = HomeLayoutMetrics.festivalRailHeight(context);
        final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
        final gap = HomeLayoutMetrics.festivalRailCardGap(context);
        final snapFrac = !kIsWeb
            ? HomeLayoutMetrics.homeRailSnapViewportFraction(context, cardW, gap)
            : null;
        return _HomeSectionShelf(
          layout: layout,
          bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, 0),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
              WebHorizontalRailList(
                height: rowH,
                padding: EdgeInsets.fromLTRB(inner, 0, inner, inner + 2),
                itemCount: 3,
                separatorBuilder: (_, __) => SizedBox(width: gap),
                snapViewportFraction: snapFrac,
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
        final inner = HomeLayoutMetrics.homeSectionShelfInnerPadding(context);
        final cols = HomeLayoutMetrics.newArrivalsColumnCount(context);
        final cellW = HomeLayoutMetrics.newArrivalCardWidthInShelf(context, cols);
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
        return _HomeSectionShelf(
          layout: layout,
          bottomSpacing: HomeLayoutMetrics.homeSectionBottomSpacing(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(inner, inner + 2, inner, 0),
                child: HomeStorefrontSectionHeader(
                  title: title,
                  badgeLabel: sectionBadge,
                  onViewAll: null,
                ),
              ),
              SizedBox(height: HomeLayoutMetrics.sectionHeaderToContentGap(context)),
              Padding(
                padding: EdgeInsets.fromLTRB(inner, 0, inner, inner + 2),
                child: grid,
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
