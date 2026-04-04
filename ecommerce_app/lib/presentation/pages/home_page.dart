import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/home_content/state/home_product_section_queries.dart';
import '../../features/home_content/state/home_storefront_providers.dart';
import '../../features/catalog/state/product_list_providers.dart';
import '../../features/catalog/state/shop_categories_provider.dart';
import '../utils/main_shell_navigation.dart';
import '../widgets/home_hero_carousel.dart';
import '../widgets/home_horizontal_product_section.dart';
import '../widgets/home_layout_metrics.dart';
import '../widgets/home_top_categories_row.dart';
import '../widgets/state_widgets.dart';
import '../widgets/storefront_home_header.dart';
import 'catalog_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  static const _sectionCount = 6;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.listenManual<Map<int, int>>(
      storefrontScrollToTopSignalProvider,
      (previous, next) {
        final prevSignal = previous?[StorefrontTab.home.shellIndex] ?? 0;
        final nextSignal = next[StorefrontTab.home.shellIndex] ?? 0;
        if (nextSignal == prevSignal) return;
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> onRefresh() async {
      ref.read(storefrontCatalogRevisionProvider.notifier).bump();
      ref.invalidate(homeHeroBannersStorefrontProvider);
      ref.invalidate(homeTopCategoriesStorefrontProvider);
      ref.invalidate(shopCategoriesStorefrontProvider);
      ref.invalidate(catalogFilterCategoriesProvider);
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: kStorefrontHomeToolbarHeight,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        scrolledUnderElevation: 2,
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        flexibleSpace: Align(
          alignment: Alignment.bottomCenter,
          child: StorefrontHomeHeaderBody(
            onSearchTap: () => Navigator.of(context).pushNamed('/search'),
          ),
        ),
      ),
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.backgroundCream,
                Color(0xFFFFFAF3),
                AppColors.backgroundCream,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: RefreshIndicator(
            color: AppColors.brandSaffron,
            onRefresh: onRefresh,
            child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              top: AppSpacing.cardGap,
              bottom: AppSpacing.section,
            ),
            itemCount: HomePage._sectionCount,
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return const _HomeHeroSlot();
                case 1:
                  return const _HomeTopCategoriesSlot();
                case 2:
                  return HomeHorizontalProductSection(
                    title: 'Popular Products',
                    query: kHomePopularProductsQuery,
                    layout: HomeStorefrontProductLayout.popularRail,
                    sectionBadge: 'Popular',
                    onViewAll: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CatalogPage(
                          title: 'Popular Products',
                          popularOnly: true,
                        ),
                      ),
                    ),
                    emptyMessage: 'Popular products will appear here as customers shop more.',
                  );
                case 3:
                  return HomeHorizontalProductSection(
                    title: 'Recommended For You',
                    query: kHomeRecommendedProductsQuery,
                    layout: HomeStorefrontProductLayout.recommendedRail,
                    sectionBadge: 'For you',
                    onViewAll: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CatalogPage(
                          title: 'Recommended For You',
                          recommendedOnly: true,
                        ),
                      ),
                    ),
                    emptyMessage: 'No recommendations right now. Explore our catalog for more products.',
                  );
                case 4:
                  return HomeHorizontalProductSection(
                    title: 'Festival Specials',
                    query: kHomeFestivalProductsQuery,
                    layout: HomeStorefrontProductLayout.festivalBannerRail,
                    sectionBadge: 'Festival',
                    onViewAll: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CatalogPage(
                          title: 'Festival Specials',
                          festivalSpecialOnly: true,
                        ),
                      ),
                    ),
                    emptyMessage: 'Festival specials are coming soon. Please check back shortly.',
                  );
                case 5:
                  return HomeHorizontalProductSection(
                    title: 'New Arrivals',
                    query: kHomeNewArrivalsQuery,
                    layout: HomeStorefrontProductLayout.newArrivalsGrid,
                    sectionBadge: 'New',
                    onViewAll: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CatalogPage(
                          title: 'New Arrivals',
                        ),
                      ),
                    ),
                    emptyMessage: 'No new arrivals yet. We are adding fresh products soon.',
                  );
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
        ),
        ),
      ),
    );
  }
}

class _HomeHeroSlot extends ConsumerWidget {
  const _HomeHeroSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeHeroBannersStorefrontProvider);
    return async.when(
      data: (banners) {
        if (banners.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
            child: PageEmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No banners yet',
              subtitle: 'Add hero banners in Admin → Homepage.',
              action: FilledButton.tonal(
                onPressed: () => openStorefrontTab(ref, context, StorefrontTab.categories),
                child: const Text('Browse shop'),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.section),
          child: HomeHeroCarousel(
            banners: banners,
            height: HomeLayoutMetrics.heroHeight(context),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: HomeLayoutMetrics.heroHeight(context),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.brandSaffron,
              ),
            ),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
        child: Text(
          'Could not load banners.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _HomeTopCategoriesSlot extends ConsumerWidget {
  const _HomeTopCategoriesSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeTopCategoriesStorefrontProvider);
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.section),
          child: HomeTopCategoriesRow(
            items: items,
            circleSize: HomeLayoutMetrics.categoryIconSize(context),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 22,
              width: 160,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 8,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.page),
                itemBuilder: (_, __) => Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
