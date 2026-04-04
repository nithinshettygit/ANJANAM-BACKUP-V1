import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/catalog/domain/shop_category.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/catalog/state/shop_categories_provider.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_provider.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Storefront Shop tab: category grid from Supabase [categories] (all `is_active` rows).
class ShopCategoriesPage extends ConsumerStatefulWidget {
  const ShopCategoriesPage({super.key});

  @override
  ConsumerState<ShopCategoriesPage> createState() => _ShopCategoriesPageState();
}

enum _ShopCategorySortMode { adminOrder, nameAsc, nameDesc }

class _ShopCategoriesPageState extends ConsumerState<ShopCategoriesPage> {
  bool _showOnlyWithProducts = false;
  _ShopCategorySortMode _sortMode = _ShopCategorySortMode.adminOrder;
  String? _selectedCategorySlug;
  final ScrollController _scrollController = ScrollController();

  static const _gridSpacing = 12.0;
  static const _horizontalPadding = 16.0;

  @override
  void initState() {
    super.initState();
    ref.listenManual<Map<int, int>>(
      storefrontScrollToTopSignalProvider,
      (previous, next) {
        final prevSignal = previous?[StorefrontTab.categories.shellIndex] ?? 0;
        final nextSignal = next[StorefrontTab.categories.shellIndex] ?? 0;
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

  int _crossAxisCount(double width) {
    if (width >= 1100) return 4;
    if (width >= 720) return 3;
    return 2;
  }

  double _childAspectRatio(double width) {
    // Slightly taller cards on very narrow screens for readable titles.
    if (width < 360) return 0.78;
    return 0.82;
  }

  Future<void> _openFilterSheet() async {
    var showOnlyWithProducts = _showOnlyWithProducts;
    var sortMode = _sortMode;
    var selectedCategorySlug = _selectedCategorySlug;
    final categories = ref.read(shopCategoriesStorefrontProvider).asData?.value ?? const <ShopCategory>[];
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
          child: StatefulBuilder(
            builder: (ctx, setLocal) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Category filters', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: selectedCategorySlug,
                  decoration: const InputDecoration(
                    labelText: 'Select category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...categories.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.slug,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => selectedCategorySlug = v),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Only categories with products'),
                  subtitle: const Text('Hide categories with zero products'),
                  value: showOnlyWithProducts,
                  onChanged: (v) => setLocal(() => showOnlyWithProducts = v),
                ),
                const Divider(height: 20),
                Text('Select category order', style: Theme.of(ctx).textTheme.titleSmall),
                RadioListTile<_ShopCategorySortMode>(
                  contentPadding: EdgeInsets.zero,
                  value: _ShopCategorySortMode.adminOrder,
                  groupValue: sortMode,
                  title: const Text('Default order'),
                  onChanged: (v) => setLocal(() => sortMode = v!),
                ),
                RadioListTile<_ShopCategorySortMode>(
                  contentPadding: EdgeInsets.zero,
                  value: _ShopCategorySortMode.nameAsc,
                  groupValue: sortMode,
                  title: const Text('Name (A-Z)'),
                  onChanged: (v) => setLocal(() => sortMode = v!),
                ),
                RadioListTile<_ShopCategorySortMode>(
                  contentPadding: EdgeInsets.zero,
                  value: _ShopCategorySortMode.nameDesc,
                  groupValue: sortMode,
                  title: const Text('Name (Z-A)'),
                  onChanged: (v) => setLocal(() => sortMode = v!),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setLocal(() {
                          selectedCategorySlug = null;
                          showOnlyWithProducts = false;
                          sortMode = _ShopCategorySortMode.adminOrder;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (applied == true && mounted) {
      setState(() {
        _selectedCategorySlug = selectedCategorySlug;
        _showOnlyWithProducts = showOnlyWithProducts;
        _sortMode = sortMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCategories = ref.watch(shopCategoriesStorefrontProvider);
    final wishlistCount = ref.watch(wishlistProvider).length;
    final cart = ref.watch(
      cartControllerProvider.select((async) => async.value),
    );
    final cartItemCount = cart?.items.fold<int>(0, (sum, e) => sum + e.quantity) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shop',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => Navigator.of(context).pushNamed('/wishlist'),
            icon: Badge(
              isLabelVisible: wishlistCount > 0,
              label: Text('$wishlistCount'),
              child: const Icon(Icons.favorite_border),
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
                            Icon(
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
      body: asyncCategories.when(
        loading: () => LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return PageLoadingGrid(
              crossAxisCount: _crossAxisCount(w),
              childAspectRatio: _childAspectRatio(w),
              itemCount: 8,
            );
          },
        ),
        error: (e, _) => PageRefreshableBody(
          onRefresh: () async {
            ref.invalidate(shopCategoriesStorefrontProvider);
            ref.read(storefrontCatalogRevisionProvider.notifier).bump();
          },
          child: PageErrorState(
            title: 'Could not load categories',
            message: e.toString(),
            onRetry: () {
              ref.invalidate(shopCategoriesStorefrontProvider);
              ref.read(storefrontCatalogRevisionProvider.notifier).bump();
            },
          ),
        ),
        data: (categories) {
          var shown = [...categories];
          if (_selectedCategorySlug != null && _selectedCategorySlug!.isNotEmpty) {
            shown = shown.where((c) => c.slug == _selectedCategorySlug).toList();
          }
          if (_showOnlyWithProducts) {
            shown = shown.where((c) => c.productCount > 0).toList();
          }
          switch (_sortMode) {
            case _ShopCategorySortMode.adminOrder:
              break;
            case _ShopCategorySortMode.nameAsc:
              shown.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              break;
            case _ShopCategorySortMode.nameDesc:
              shown.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
              break;
          }

          if (categories.isEmpty) {
            return PageRefreshableBody(
              onRefresh: () async {
                ref.invalidate(shopCategoriesStorefrontProvider);
                ref.read(storefrontCatalogRevisionProvider.notifier).bump();
              },
              child: PageEmptyState(
                icon: Icons.category_outlined,
                title: 'No categories yet',
                subtitle:
                    'When your team adds categories in the admin panel and marks them for the Shop, they will show up here.',
                action: FilledButton.tonal(
                  onPressed: () {
                    ref.invalidate(shopCategoriesStorefrontProvider);
                    ref.read(storefrontCatalogRevisionProvider.notifier).bump();
                  },
                  child: const Text('Refresh'),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(shopCategoriesStorefrontProvider);
              ref.read(storefrontCatalogRevisionProvider.notifier).bump();
              await ref.read(shopCategoriesStorefrontProvider.future);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final crossAxis = _crossAxisCount(w);
                final aspect = _childAspectRatio(w);
                return CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        _horizontalPadding,
                        8,
                        _horizontalPadding,
                        4,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Browse by category',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        _horizontalPadding,
                        0,
                        _horizontalPadding,
                        24,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxis,
                          childAspectRatio: aspect,
                          crossAxisSpacing: _gridSpacing,
                          mainAxisSpacing: _gridSpacing,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final c = shown[index];
                            return _ShopCategoryCard(
                              category: c,
                              onOpen: () {
                                Navigator.of(context).pushNamed(
                                  '/products',
                                  arguments: {
                                    'category': c.slug,
                                    'title': c.name,
                                  },
                                );
                              },
                            );
                          },
                          childCount: shown.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ShopCategoryCard extends StatefulWidget {
  final ShopCategory category;
  final VoidCallback onOpen;

  const _ShopCategoryCard({
    required this.category,
    required this.onOpen,
  });

  @override
  State<_ShopCategoryCard> createState() => _ShopCategoryCardState();
}

class _ShopCategoryCardState extends State<_ShopCategoryCard> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final elevation = _hover || _pressed ? 6.0 : 2.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
          elevation: elevation,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          color: scheme.surface,
          child: InkWell(
            onTap: widget.onOpen,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _CategoryImage(
                          url: widget.category.imageUrl,
                          name: widget.category.name,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (widget.category.productCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${widget.category.productCount} products',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  final String? url;
  final String name;

  const _CategoryImage({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainerHighest;
    final u = url?.trim();
    if (u == null || u.isEmpty) {
      return ColoredBox(
        color: placeholder,
        child: Center(
          child: Icon(
            Icons.category_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      placeholder: (_, __) => ColoredBox(color: placeholder),
      errorWidget: (_, __, ___) => ColoredBox(
        color: placeholder,
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
