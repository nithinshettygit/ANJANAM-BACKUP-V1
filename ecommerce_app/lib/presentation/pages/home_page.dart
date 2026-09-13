import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/web_horizontal_rail_list.dart';
import '../widgets/state_widgets.dart';
import '../widgets/storefront_home_header.dart'
    show
        StorefrontHomeHeaderBody,
        kStorefrontHomeToolbarHeight,
        kStorefrontHomeWebInlineSearchMinWidth,
        kStorefrontHomeWebToolbarHeight;
import 'catalog_page.dart';
import '../../l10n/app_localizations.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  static const _sectionCount = 6;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  /// 0 = full header (brand + icons), 1 = collapsed (search only). Driven by scroll direction.
  late final AnimationController _headerCollapseAnim;

  /// Last [ScrollPosition.pixels] to infer scroll direction (native home only).
  double? _lastScrollPixels;

  static const Duration _headerCollapseDuration = Duration(milliseconds: 260);
  static const Duration _headerExpandDuration = Duration(milliseconds: 240);
  static const double _scrollDirectionMinDelta = 4.0;

  @override
  void initState() {
    super.initState();
    _headerCollapseAnim = AnimationController(
      vsync: this,
      duration: _headerCollapseDuration,
      reverseDuration: _headerExpandDuration,
    );
    _scrollController.addListener(_onHomeScrollDirection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || kIsWeb) return;
      if (_scrollController.hasClients) {
        _lastScrollPixels = _scrollController.position.pixels;
      }
    });
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
  void activate() {
    super.activate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || kIsWeb) return;
      if (_scrollController.hasClients) {
        _lastScrollPixels = _scrollController.position.pixels;
      }
    });
  }

  /// Flipkart-style: collapse only while scrolling **down**; expand as soon as user scrolls **up**
  /// (any offset). Not tied to distance from top.
  void _onHomeScrollDirection() {
    if (kIsWeb || !_scrollController.hasClients) return;

    final pixels = _scrollController.position.pixels;
    if (pixels < 0) {
      _lastScrollPixels = pixels;
      return;
    }

    if (_lastScrollPixels == null) {
      _lastScrollPixels = pixels;
      return;
    }

    final delta = pixels - _lastScrollPixels!;
    _lastScrollPixels = pixels;

    if (delta.abs() < _scrollDirectionMinDelta) return;

    if (delta > 0) {
      _headerCollapseAnim.animateTo(
        1.0,
        duration: _headerCollapseDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      _headerCollapseAnim.animateTo(
        0.0,
        duration: _headerExpandDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onHomeScrollDirection);
    _headerCollapseAnim.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _homeFeedList(Future<void> Function() onRefresh) {
    final localizations = AppLocalizations.of(context);
    return DecoratedBox(
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
          padding: EdgeInsets.only(
            top: HomeLayoutMetrics.homeListTopPadding(context),
            bottom: HomeLayoutMetrics.homeListBottomPadding(context),
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
                  title: localizations.popularProducts,
                  query: kHomePopularProductsQuery,
                  layout: HomeStorefrontProductLayout.popularRail,
                  sectionBadge: localizations.popular,
                  onViewAll: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CatalogPage(
                        title: localizations.popularProducts,
                        popularOnly: true,
                      ),
                    ),
                  ),
                  emptyMessage: localizations.popularEmpty,
                );
              case 3:
                return HomeHorizontalProductSection(
                  title: localizations.recommendedForYou,
                  query: kHomeRecommendedProductsQuery,
                  layout: HomeStorefrontProductLayout.recommendedRail,
                  sectionBadge: localizations.forYou,
                  onViewAll: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CatalogPage(
                        title: localizations.recommendedForYou,
                        recommendedOnly: true,
                      ),
                    ),
                  ),
                  emptyMessage: localizations.recommendationsEmpty,
                );
              case 4:
                return HomeHorizontalProductSection(
                  title: localizations.festivalSpecials,
                  query: kHomeFestivalProductsQuery,
                  layout: HomeStorefrontProductLayout.festivalBannerRail,
                  sectionBadge: localizations.festival,
                  onViewAll: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CatalogPage(
                        title: localizations.festivalSpecials,
                        festivalSpecialOnly: true,
                      ),
                    ),
                  ),
                  emptyMessage: localizations.festivalEmpty,
                );
              case 5:
                return HomeHorizontalProductSection(
                  title: localizations.newArrivals,
                  query: kHomeNewArrivalsQuery,
                  layout: HomeStorefrontProductLayout.newArrivalsGrid,
                  sectionBadge: localizations.newLabel,
                  onViewAll: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CatalogPage(
                        title: localizations.newArrivals,
                      ),
                    ),
                  ),
                  emptyMessage: localizations.newArrivalsEmpty,
                );
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
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

    final screenW = MediaQuery.sizeOf(context).width;
    final webWideHeader =
        kIsWeb && screenW >= kStorefrontHomeWebInlineSearchMinWidth;

    if (!kIsWeb) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedBuilder(
                  animation: _headerCollapseAnim,
                  builder: (context, _) {
                    final t = _headerCollapseAnim.value.clamp(0.0, 1.0);
                    return Material(
                      color: AppColors.surfaceCard,
                      elevation: lerpDouble(1, 3, t)!,
                      shadowColor: Colors.black.withValues(alpha: 0.08),
                      surfaceTintColor: Colors.transparent,
                      child: StorefrontHomeHeaderBody(
                        onSearchTap: () => Navigator.of(context).pushNamed('/search'),
                        mobileScrollCollapseT: t,
                      ),
                    );
                  },
                ),
                Expanded(child: _homeFeedList(onRefresh)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: webWideHeader
            ? kStorefrontHomeWebToolbarHeight
            : kStorefrontHomeToolbarHeight,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        scrolledUnderElevation: 2,
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        flexibleSpace: Align(
          alignment: webWideHeader
              ? Alignment.center
              : Alignment.bottomCenter,
          child: StorefrontHomeHeaderBody(
            onSearchTap: () => Navigator.of(context).pushNamed('/search'),
          ),
        ),
      ),
      body: SafeArea(
        child: _homeFeedList(onRefresh),
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
            padding: EdgeInsets.fromLTRB(
              HomeLayoutMetrics.pageHorizontal(context),
              0,
              HomeLayoutMetrics.pageHorizontal(context),
              AppSpacing.page,
            ),
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
          padding: EdgeInsets.only(
            top: HomeLayoutMetrics.homeHeroTopMargin(context),
            bottom: HomeLayoutMetrics.homeHeroBottomMargin(context),
          ),
          child: HomeHeroCarousel(
            banners: banners,
            height: HomeLayoutMetrics.heroHeight(context),
          ),
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.fromLTRB(
          HomeLayoutMetrics.pageHorizontal(context),
          0,
          HomeLayoutMetrics.pageHorizontal(context),
          AppSpacing.page,
        ),
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
        padding: EdgeInsets.fromLTRB(
          HomeLayoutMetrics.pageHorizontal(context),
          0,
          HomeLayoutMetrics.pageHorizontal(context),
          AppSpacing.page,
        ),
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
          padding: EdgeInsets.only(
            bottom: HomeLayoutMetrics.homeSectionBottomSpacing(context),
          ),
          child: HomeTopCategoriesRow(
            items: items,
            circleSize: HomeLayoutMetrics.categoryIconSize(context),
          ),
        );
      },
      loading: () {
        final cs = HomeLayoutMetrics.categoryIconSize(context);
        final ring = cs + 4;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: HomeLayoutMetrics.pageHorizontal(context),
                ),
                child: Container(
                  height: 22,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              SizedBox(
                height: HomeLayoutMetrics.homeCategoryHeaderToScrollerGap(context),
              ),
              WebHorizontalRailList(
                height: cs + 48,
                padding: EdgeInsets.symmetric(
                  horizontal: HomeLayoutMetrics.pageHorizontal(context),
                ),
                itemCount: 8,
                separatorBuilder: (_, __) => SizedBox(
                  width: HomeLayoutMetrics.homeCategoryScrollerGap(context),
                ),
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HomeLayoutMetrics.homeCategoryChipPaddingH,
                  ),
                  child: SizedBox(
                    width: cs + HomeLayoutMetrics.homeCategoryChipLabelSlotExtra,
                    child: Column(
                      children: [
                        Container(
                          width: ring,
                          height: ring,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
