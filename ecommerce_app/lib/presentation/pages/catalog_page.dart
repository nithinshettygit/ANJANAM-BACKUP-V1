import 'package:ecommerce_app/core/layout/storefront_web_layout.dart';
import 'package:ecommerce_app/core/theme/wishlist_heart_sizes.dart';
import 'package:ecommerce_app/features/cart/domain/entities/cart.dart';
import 'package:ecommerce_app/features/cart/domain/entities/cart_item.dart';
import 'package:flutter/foundation.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';
import 'package:ecommerce_app/features/catalog/domain/product_sort_option.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_provider.dart';
import 'package:ecommerce_app/presentation/utils/buy_now_navigation.dart';
import 'package:ecommerce_app/presentation/utils/cart_feedback_snackbar.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/utils/storefront_category_slug.dart';
import 'package:ecommerce_app/presentation/utils/storefront_product_navigation.dart';
import 'package:ecommerce_app/presentation/widgets/product_card.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:ecommerce_app/presentation/utils/storefront_title_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Applied when user taps Apply in the filter sheet.
class _CatalogFilterResult {
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final ProductSortOption sort;

  const _CatalogFilterResult({
    required this.minPrice,
    required this.maxPrice,
    required this.inStockOnly,
    required this.sort,
  });
}

class CatalogPage extends ConsumerStatefulWidget {
  final String? category;
  final String title;
  final bool popularOnly;
  final bool recommendedOnly;
  final bool festivalSpecialOnly;

  const CatalogPage({
    super.key,
    this.category,
    this.title = 'Product Catalog',
    this.popularOnly = false,
    this.recommendedOnly = false,
    this.festivalSpecialOnly = false,
  });

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();

  String? _categoryFilter;
  double? _minPrice;
  double? _maxPrice;
  bool _inStockOnly = false;
  ProductSortOption _sort = ProductSortOption.newest;

  List<Product> _items = [];
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  Object? _loadError;

  int get _activeFilterCount {
    var n = 0;
    if (_minPrice != null) n++;
    if (_maxPrice != null) n++;
    if (_inStockOnly) n++;
    if (_sort != ProductSortOption.newest) n++;
    return n;
  }

  @override
  void initState() {
    super.initState();
    _categoryFilter = normalizeStorefrontCategorySlug(widget.category);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore || _loadError != null) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _loadError = null;
      _items = [];
      _nextOffset = 0;
      _hasMore = true;
    });
    try {
      final repo = ref.read(productRepositoryProvider);
      final page = await repo.fetchProducts(
        category: _categoryFilter,
        nameSearch: null,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        inStockOnly: _inStockOnly,
        popularOnly: widget.popularOnly,
        recommendedOnly: widget.recommendedOnly,
        festivalSpecialOnly: widget.festivalSpecialOnly,
        sort: _sort,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items = page;
        _nextOffset = page.length;
        _hasMore = page.length >= _pageSize;
        _loadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loadError != null) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final page = await repo.fetchProducts(
        category: _categoryFilter,
        nameSearch: null,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        inStockOnly: _inStockOnly,
        popularOnly: widget.popularOnly,
        recommendedOnly: widget.recommendedOnly,
        festivalSpecialOnly: widget.festivalSpecialOnly,
        sort: _sort,
        limit: _pageSize,
        offset: _nextOffset,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page];
        _nextOffset += page.length;
        _hasMore = page.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load more: $e')),
      );
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_CatalogFilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CatalogFilterSheet(
        initialMin: _minPrice,
        initialMax: _maxPrice,
        initialInStockOnly: _inStockOnly,
        initialSort: _sort,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _minPrice = result.minPrice;
      _maxPrice = result.maxPrice;
      _inStockOnly = result.inStockOnly;
      _sort = result.sort;
    });
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);
    final cart = ref.watch(
      cartControllerProvider.select((async) => async.value),
    );
    final cartItemCount = cart?.items.fold<int>(0, (sum, e) => sum + e.quantity) ?? 0;

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 48,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
          tooltip: canPop ? 'Back' : 'Home',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: storefrontAppBarEmphasisTitleStyle(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Wishlist',
            iconSize: WishlistHeartSizes.appBar,
            onPressed: () => Navigator.of(context).pushNamed('/wishlist'),
            icon: Badge(
              isLabelVisible: wishlist.isNotEmpty,
              label: Text('${wishlist.length}'),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).pushNamed('/search'),
                      child: const SizedBox(
                        height: 42,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 18),
                              SizedBox(width: 8),
                              Text('Search products'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: Material(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _openFilterSheet,
                      child: SizedBox(
                        height: 42,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _activeFilterCount > 0
                                ? Badge(
                                    label: Text('$_activeFilterCount'),
                                    child: Icon(
                                      Icons.tune_rounded,
                                      size: 18,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  )
                                : Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                            const SizedBox(width: 6),
                            Text(
                              'Filter',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: kIsWeb
          ? WebMaxWidthCenter(child: _buildBody(context, wishlist, cart))
          : _buildBody(context, wishlist, cart),
    );
  }

  Widget _buildBody(BuildContext context, Set<String> wishlist, Cart? cart) {
    if (_loadingInitial) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = catalogGridCrossAxisCount(width);
          return PageLoadingGrid(
            crossAxisCount: crossAxisCount,
            childAspectRatio: catalogGridChildAspectRatio(width),
          );
        },
      );
    }

    if (_loadError != null && _items.isEmpty) {
      return PageRefreshableBody(
        onRefresh: _loadInitial,
        child: PageErrorState(
          title: 'Could not load catalog',
          message:
              'Check your connection and try again.\n${_loadError.toString()}',
          onRetry: _loadInitial,
        ),
      );
    }

    if (_items.isEmpty) {
      return PageRefreshableBody(
        onRefresh: _loadInitial,
        child: PageEmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'No matching products',
          subtitle: 'Try widening the price range, another category, or turning off “In stock only”.',
          action: FilledButton.tonal(
            onPressed: _openFilterSheet,
            child: const Text('Adjust filters'),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = catalogGridCrossAxisCount(width);
        final spacing = catalogGridSpacing(width);
        final hPad = catalogHorizontalPadding(context);
        final aspectRatio = catalogGridChildAspectRatio(width);
        final cardWidth =
            (width - hPad * 2 - (crossAxisCount - 1) * spacing) / crossAxisCount;

        List<CartItem> cartLinesFor(String productId) {
          return cart?.items.where((e) => e.productId == productId).toList() ?? const [];
        }

        int? lineQty(String productId) {
          final lines = cartLinesFor(productId);
          if (lines.length == 1) return lines.first.quantity;
          return null;
        }

        String? soleCartVariantId(String productId) {
          final lines = cartLinesFor(productId);
          return lines.length == 1 ? lines.first.variantId : null;
        }

        final footerCount = (_loadingMore && _hasMore) ? 1 : 0;
        final childCount = _items.length + footerCount;

        return RefreshIndicator(
          onRefresh: _loadInitial,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hPad, kIsWeb ? 16 : 8, hPad, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${_sort.storefrontLabel} · ${_items.length}${_hasMore ? '+' : ''} shown',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _items.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final product = _items[index];
                      final inCart =
                          cart?.items.any((e) => e.productId == product.id) ?? false;
                      return ProductCard(
                        product: product,
                        width: cardWidth,
                        onTap: () => navigateToStorefrontProductDetails(
                          context,
                          ref,
                          product.id,
                        ),
                        isWishlisted: wishlist.contains(product.id),
                        onToggleWishlist: () {
                          ref.read(wishlistControllerProvider.notifier).toggle(product.id);
                        },
                        isInCart: inCart,
                        cartLineQuantity: lineQty(product.id),
                        onUpdateCartQuantity: (q) async {
                          await ref
                              .read(cartControllerProvider.notifier)
                              .updateQuantity(
                                productId: product.id,
                                variantId: soleCartVariantId(product.id),
                                quantity: q,
                              );
                        },
                        onRemoveFromCart: () async {
                          await ref
                              .read(cartControllerProvider.notifier)
                              .removeItem(
                                productId: product.id,
                                variantId: soleCartVariantId(product.id),
                              );
                        },
                        onGoToCart: () => navigateToCartPage(ref, context),
                        onAddToCart: (qty) async {
                          await ref.read(cartControllerProvider.notifier).addItem(
                                productId: product.id,
                                quantity: qty,
                              );
                          if (!context.mounted) return;
                          showAddedToCartSnackBar(
                            ref,
                            context,
                            productTitle: product.title,
                          );
                        },
                        onBuyNow: (qty) => openBuyNowCheckout(
                              context,
                              ref,
                              productId: product.id,
                              quantity: qty,
                            ),
                      );
                    },
                    childCount: childCount,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogFilterSheet extends StatefulWidget {
  final double? initialMin;
  final double? initialMax;
  final bool initialInStockOnly;
  final ProductSortOption initialSort;

  const _CatalogFilterSheet({
    required this.initialMin,
    required this.initialMax,
    required this.initialInStockOnly,
    required this.initialSort,
  });

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late bool _inStockOnly;
  late ProductSortOption _sort;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.initialMin != null ? _trimTrailingZeros(widget.initialMin!) : '',
    );
    _maxController = TextEditingController(
      text: widget.initialMax != null ? _trimTrailingZeros(widget.initialMax!) : '',
    );
    _inStockOnly = widget.initialInStockOnly;
    _sort = widget.initialSort;
  }

  static String _trimTrailingZeros(double v) {
    final s = v.toStringAsFixed(2);
    if (s.endsWith('.00')) return s.substring(0, s.length - 3);
    if (s.endsWith('0') && s.contains('.')) {
      return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  double? _parsePrice(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', ''));
  }

  void _apply() {
    Navigator.of(context).pop(
      _CatalogFilterResult(
        minPrice: _parsePrice(_minController.text),
        maxPrice: _parsePrice(_maxController.text),
        inStockOnly: _inStockOnly,
        sort: _sort,
      ),
    );
  }

  void _reset() {
    setState(() {
      _minController.clear();
      _maxController.clear();
      _inStockOnly = false;
      _sort = ProductSortOption.newest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...ProductSortOption.values.map(
              (o) => RadioListTile<ProductSortOption>(
                title: Text(o.storefrontLabel),
                value: o,
                groupValue: _sort,
                onChanged: (v) {
                  if (v != null) setState(() => _sort = v);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const Divider(height: 24),
            Text('Price (INR)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    decoration: const InputDecoration(
                      labelText: 'Min',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    decoration: const InputDecoration(
                      labelText: 'Max',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('In stock only'),
              subtitle: const Text('Hide products with zero inventory'),
              value: _inStockOnly,
              onChanged: (v) => setState(() => _inStockOnly = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
