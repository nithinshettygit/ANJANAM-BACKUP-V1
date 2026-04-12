import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/wishlist_heart_sizes.dart';
import '../../features/articles/providers/articles_providers.dart';
import '../../features/articles/widgets/explore_articles_sections.dart';
import '../../features/cart/state/cart_controller.dart';
import '../../features/explore_suggestions/providers/explore_suggestions_providers.dart';
import '../../features/explore_suggestions/widgets/suggested_for_you_carousel.dart';
import '../../features/videos/providers/videos_providers.dart';
import '../../features/videos/widgets/explore_new_videos_swiper.dart';
import '../../features/wishlist/state/wishlist_provider.dart';
import '../utils/main_shell_navigation.dart';
import '../widgets/legal_support_links.dart';

/// Hub for media experiences (videos, music) from the main bottom nav.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ref.listenManual<Map<int, int>>(
      storefrontScrollToTopSignalProvider,
      (previous, next) {
        final prevSignal = previous?[StorefrontTab.explore.shellIndex] ?? 0;
        final nextSignal = next[StorefrontTab.explore.shellIndex] ?? 0;
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
    final screenW = MediaQuery.sizeOf(context).width;
    final exploreSectionGap =
        kIsWeb && screenW >= 1100 ? 40.0 : 12.0;
    final wishlistCount = ref.watch(wishlistProvider).length;
    final cart = ref.watch(
      cartControllerProvider.select((async) => async.value),
    );
    final cartItemCount = cart?.items.fold<int>(0, (sum, e) => sum + e.quantity) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explore',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Wishlist',
            iconSize: WishlistHeartSizes.appBar,
            onPressed: () => Navigator.of(context).pushNamed('/wishlist'),
            icon: Badge(
              isLabelVisible: wishlistCount > 0,
              label: Text('$wishlistCount'),
              child: Icon(Icons.favorite_border, size: WishlistHeartSizes.appBar),
            ),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => navigateToCartPage(ref, context),
            icon: Badge(
              isLabelVisible: cartItemCount > 0,
              label: Text('$cartItemCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeExploreSuggestionsProvider);
          ref.invalidate(publishedArticlesProvider);
          ref.invalidate(articlesRevisionProvider);
          ref.invalidate(exploreSuggestionsRevisionProvider);
          await Future.wait([
            ref.read(activeExploreSuggestionsProvider.future),
            ref.read(publishedArticlesProvider.future),
            ref.read(homeVideosPreviewProvider.future),
          ]);
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const SuggestedForYouCarousel(),
            SizedBox(height: exploreSectionGap),
            const ExploreArticlesSections(),
            SizedBox(height: exploreSectionGap),
            const ExploreNewVideosSwiper(),
            SizedBox(height: exploreSectionGap),
            _ExploreEntryCard(
              title: 'Articles',
              subtitle: 'Read free and premium knowledge PDFs',
              icon: Icons.menu_book_rounded,
              accent: const Color(0xFF5E35B1),
              badge: 'Featured',
              onTap: () => Navigator.of(context).pushNamed('/articles'),
            ),
            const SizedBox(height: 12),
            _ExploreEntryCard(
              title: 'Videos',
              subtitle: 'Watch stories, talks and highlights',
              icon: Icons.smart_display_rounded,
              accent: const Color(0xFFFF0000),
              badge: 'Popular',
              onTap: () => Navigator.of(context).pushNamed('/videos'),
            ),
            const SizedBox(height: 12),
            _ExploreEntryCard(
              title: 'Music',
              subtitle: 'Listen and browse devotional tracks',
              icon: Icons.music_note_rounded,
              accent: AppColors.forestGreen,
              badge: 'New',
              onTap: () => Navigator.of(context).pushNamed('/music'),
            ),
            const LegalSupportFooterCompact(),
          ],
        ),
      ),
    );
  }
}

class _ExploreEntryCard extends StatelessWidget {
  const _ExploreEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

