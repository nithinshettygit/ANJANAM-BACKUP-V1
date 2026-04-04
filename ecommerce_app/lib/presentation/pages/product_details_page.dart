import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/catalog/domain/product_sort_option.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';
import 'package:ecommerce_app/features/product_details/state/product_details_providers.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_provider.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';
import 'package:ecommerce_app/presentation/utils/product_price_display.dart';
import 'package:ecommerce_app/presentation/utils/buy_now_navigation.dart';
import 'package:ecommerce_app/presentation/utils/cart_feedback_snackbar.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/utils/product_availability.dart';
import 'package:ecommerce_app/presentation/utils/storefront_product_navigation.dart';
import 'package:ecommerce_app/presentation/widgets/home_product_discovery_card.dart';
import 'package:ecommerce_app/presentation/widgets/product_image_carousel.dart';
import 'package:ecommerce_app/presentation/widgets/product_quantity_stepper.dart';
import 'package:ecommerce_app/features/product_questions/widgets/product_questions_section.dart';
import 'package:ecommerce_app/presentation/widgets/product_reviews_section.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailsPage({
    super.key,
    required this.productId,
  });

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int _pendingQty = 1;

  @override
  void didUpdateWidget(covariant ProductDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _pendingQty = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(productDetailsProvider(widget.productId));
    return detailAsync.when(
      data: (detail) {
        final product = detail.product;
        final isWishlisted = ref.watch(wishlistProvider).contains(product.id);
        final cart = ref.watch(
          cartControllerProvider.select((async) => async.value),
        );
        final inCart = cart?.items.any((e) => e.productId == product.id) ?? false;
        final outOfStock = productIsOutOfStock(product);
        final stockBanner = productStockBannerText(product);
        final pricing = ProductPriceDisplay.forProduct(
          product,
          hidePromoWhenOutOfStock: true,
          outOfStock: outOfStock,
        );
        final maxQ = maxSelectableQuantity(product);
        int? lineQty;
        for (final e in cart?.items ?? []) {
          if (e.productId == product.id) {
            lineQty = e.quantity;
            break;
          }
        }
        final displayQty = (lineQty ?? _pendingQty).clamp(1, maxQ);

        return Scaffold(
          appBar: AppBar(title: const Text('Product Details')),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.read(storefrontCatalogRevisionProvider.notifier).bump();
              await ref.read(productDetailsProvider(widget.productId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                Stack(
                  children: [
                    ProductImageCarousel(
                      imageUrls: product.imageUrls,
                      height: 260,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    if (pricing.showPromo)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.marigoldOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pricing.discountPercent}% OFF',
                            style: const TextStyle(
                              color: AppColors.charcoalBlack,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.25),
                        child: IconButton(
                          onPressed: () =>
                              ref.read(wishlistControllerProvider.notifier).toggle(product.id),
                          icon: Icon(
                            isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: isWishlisted ? AppColors.errorRed : AppColors.marigoldOrange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  product.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (pricing.showPromo) ...[
                  Text(
                    'MRP',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    formatRupee(pricing.mrp!),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You pay',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.marigoldOrange,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                Text(
                  formatRupee(pricing.salePrice),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.marigoldOrange,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (product.category != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      product.category!,
                      style: const TextStyle(
                        color: AppColors.lightGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (stockBanner != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: outOfStock
                          ? AppColors.errorRed.withOpacity(0.12)
                          : AppColors.marigoldOrange.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: outOfStock
                            ? AppColors.errorRed.withOpacity(0.5)
                            : AppColors.marigoldOrange.withOpacity(0.6),
                      ),
                    ),
                    child: Text(
                      stockBanner,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: outOfStock ? AppColors.errorRed : AppColors.charcoalBlack,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  product.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                if (!outOfStock) ...[
                  Row(
                    children: [
                      Text(
                        'Quantity',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      ProductQuantityStepper(
                        quantity: displayQty,
                        minQuantity: 1,
                        maxQuantity: maxQ,
                        allowZeroOnDecrement: lineQty != null,
                        onChanged: (q) async {
                          if (lineQty != null) {
                            if (q <= 0) {
                              await ref
                                  .read(cartControllerProvider.notifier)
                                  .removeItem(productId: product.id);
                            } else {
                              await ref
                                  .read(cartControllerProvider.notifier)
                                  .updateQuantity(
                                    productId: product.id,
                                    quantity: q,
                                  );
                            }
                          } else {
                            setState(() => _pendingQty = q.clamp(1, maxQ));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                ProductReviewsSection(
                  product: product,
                  listMode: ProductReviewsListMode.embeddedPreview,
                ),
                const SizedBox(height: 16),
                ProductQuestionsSection(
                  product: product,
                  listMode: ProductQuestionsListMode.embeddedPreview,
                ),
                const SizedBox(height: 16),
                SimilarProductsSection(
                  currentProductId: product.id,
                  category: product.category,
                  title: product.title,
                  tags: product.tags,
                ),
                const SizedBox(height: 16),
                YouAlsoLikeSection(currentProductId: product.id),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: inCart ? AppColors.forestGreen : AppColors.deepGold,
                        ),
                        foregroundColor: inCart ? AppColors.forestGreen : AppColors.deepGold,
                      ),
                      onPressed: inCart
                          ? () => navigateToCartPage(ref, context)
                          : outOfStock
                              ? null
                              : () async {
                                  try {
                                    await ref.read(cartControllerProvider.notifier).addItem(
                                          productId: product.id,
                                          quantity: displayQty,
                                        );
                                    if (!context.mounted) return;
                                    showAddedToCartSnackBar(
                                      ref,
                                      context,
                                      productTitle: product.title,
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to add to cart: $e'),
                                        duration: const Duration(seconds: 4),
                                        behavior: SnackBarBehavior.fixed,
                                      ),
                                    );
                                  }
                                },
                      icon: Icon(
                        inCart ? Icons.shopping_cart_outlined : Icons.add_shopping_cart,
                      ),
                      label: Text(
                        inCart ? 'Go to Cart' : outOfStock ? 'Out of stock' : 'Add to Cart',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: outOfStock
                          ? null
                          : () => openBuyNowCheckout(
                                context,
                                ref,
                                productId: product.id,
                                quantity: displayQty,
                              ),
                      icon: const Icon(Icons.flash_on),
                      label: Text(outOfStock ? 'Unavailable' : 'Buy Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: const PageLoading(message: 'Loading product...'),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Product Details')),
        body: PageRefreshableBody(
          onRefresh: () async {
            ref.read(storefrontCatalogRevisionProvider.notifier).bump();
            await ref.read(productDetailsProvider(widget.productId).future);
          },
          child: PageErrorState(
            title: 'Product unavailable',
            message:
                'We could not load this product. It may have been removed from the store, or there may be a temporary connection issue. Pull to refresh, or open My Orders to see items you already purchased.',
            onRetry: () {
              ref.invalidate(productDetailsProvider(widget.productId));
              ref.read(storefrontCatalogRevisionProvider.notifier).bump();
            },
          ),
        ),
      ),
    );
  }
}

class SimilarProductsSection extends ConsumerWidget {
  const SimilarProductsSection({
    super.key,
    required this.currentProductId,
    required this.category,
    required this.title,
    required this.tags,
  });

  final String currentProductId;
  final String? category;
  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      similarProductsProvider(
        SimilarProductsQuery(
          currentProductId: currentProductId,
          category: category,
          title: title,
          tags: tags,
          limit: 8,
        ),
      ),
    );
    final wishlist = ref.watch(wishlistProvider);

    return async.when(
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Similar Products',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 270,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return HomeProductDiscoveryCard(
                    product: product,
                    width: 160,
                    height: 270,
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
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Similar Products',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 270,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, _) => const _SuggestionSkeletonCard(width: 160),
            ),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class YouAlsoLikeSection extends ConsumerStatefulWidget {
  const YouAlsoLikeSection({
    super.key,
    required this.currentProductId,
  });

  final String currentProductId;

  @override
  ConsumerState<YouAlsoLikeSection> createState() => _YouAlsoLikeSectionState();
}

class _YouAlsoLikeSectionState extends ConsumerState<YouAlsoLikeSection> {
  static const int _pageSize = 8;
  final ScrollController _scrollController = ScrollController();
  final List<Product> _items = [];
  final Set<String> _seenIds = <String>{};
  bool _loading = false;
  bool _loadedInitial = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant YouAlsoLikeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentProductId != widget.currentProductId) {
      _items.clear();
      _seenIds.clear();
      _loading = false;
      _loadedInitial = false;
      _hasMore = true;
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || !_hasMore || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 260) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final page = await repo.fetchProducts(
        sort: ProductSortOption.newest,
        limit: _pageSize,
        offset: _items.length,
      );
      final before = _items.length;
      for (final p in page) {
        if (p.id == widget.currentProductId) continue;
        if (_seenIds.add(p.id)) {
          _items.add(p);
        }
      }
      _hasMore = page.length == _pageSize && _items.length > before;
    } catch (_) {
      _hasMore = false;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadedInitial = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);
    if (!_loadedInitial && _items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You also like',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 270,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => const _SuggestionSkeletonCard(width: 160),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You also like',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 270,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _items.length + (_loading ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return const _SuggestionSkeletonCard(width: 160);
              }
              final product = _items[index];
              return HomeProductDiscoveryCard(
                product: product,
                width: 160,
                height: 270,
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
    );
  }
}

class _SuggestionSkeletonCard extends StatelessWidget {
  const _SuggestionSkeletonCard({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.65);
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: width,
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
                      width: width * 0.8,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: width * 0.48,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 12,
                      width: width * 0.52,
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
