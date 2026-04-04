import 'dart:async';
import 'dart:math' as math;

import 'package:ecommerce_app/core/layout/storefront_web_layout.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/search/models/product_suggestion.dart';
import 'package:ecommerce_app/features/search/providers/search_suggestions_provider.dart';
import 'package:ecommerce_app/features/search/widgets/search_bar_widget.dart';
import 'package:ecommerce_app/features/search/widgets/search_suggestions_list.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_provider.dart';
import 'package:ecommerce_app/presentation/utils/buy_now_navigation.dart';
import 'package:ecommerce_app/presentation/utils/cart_feedback_snackbar.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/utils/storefront_product_navigation.dart';
import 'package:ecommerce_app/presentation/widgets/product_card.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:ecommerce_app/presentation/widgets/storefront_home_header.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Storefront search: debounced autocomplete (title, category, description, tags via RPC) and full results after submit.
class ProductSearchPage extends ConsumerStatefulWidget {
  final String? initialQuery;

  const ProductSearchPage({super.key, this.initialQuery});

  @override
  ConsumerState<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends ConsumerState<ProductSearchPage> {
  static const _searchLimit = 48;
  static const _suggestionDebounceMs = 300;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _suggestionDebounce;
  String _submittedQuery = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    _controller = TextEditingController(text: initial);
    _focusNode = FocusNode();
    _submittedQuery = initial;
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _controller.text.trim().length >= 2) {
      _scheduleSuggestionFetch(_controller.text);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _suggestionDebounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSuggestionFetch(String value) {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(
      const Duration(milliseconds: _suggestionDebounceMs),
      () {
        if (!mounted) return;
        ref.read(searchSuggestionsProvider.notifier).requestSuggestions(value);
      },
    );
  }

  ProductListQuery get _listQuery => ProductListQuery(
        nameSearch: _submittedQuery.isEmpty ? null : _submittedQuery,
        limit: _searchLimit,
        offset: 0,
      );

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(storefrontCatalogRevisionProvider.notifier).bump();
    if (_submittedQuery.isEmpty) return;
    await ref.read(productListProvider(_listQuery).future);
  }

  void _clearAll() {
    _suggestionDebounce?.cancel();
    _controller.clear();
    _submittedQuery = '';
    ref.read(searchSuggestionsProvider.notifier).clear();
    setState(() {});
  }

  void _onSubmitted(String raw) {
    _suggestionDebounce?.cancel();
    final next = raw.trim();
    setState(() => _submittedQuery = next);
    FocusScope.of(context).unfocus();
  }

  Future<void> _onSuggestionTap(ProductSuggestion s) async {
    _suggestionDebounce?.cancel();
    FocusScope.of(context).unfocus();
    ref.read(searchSuggestionsProvider.notifier).clear();
    if (!context.mounted) return;
    await navigateToStorefrontProductDetails(context, ref, s.id);
  }

  bool get _showSuggestions {
    if (!_focusNode.hasFocus) return false;
    return _controller.text.trim().length >= 2;
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);
    final cart = ref.watch(
      cartControllerProvider.select((async) => async.value),
    );
    final suggestionState = ref.watch(searchSuggestionsProvider);

    final productsAsync = _submittedQuery.isEmpty
        ? const AsyncValue<List<Product>>.data([])
        : ref.watch(productListProvider(_listQuery));

    final typedForSuggestions = _controller.text.trim();
    final waitingDebounced = _showSuggestions &&
        typedForSuggestions.length >= 2 &&
        typedForSuggestions != (suggestionState.activeQuery ?? '') &&
        !suggestionState.loading;

    final screenW = MediaQuery.sizeOf(context).width;
    // Mirror leading width so [centerTitle] centers the field on the full toolbar.
    const leadingActionWidth = 56.0;
    final searchBarMaxW = math.min(
      kStorefrontSearchBarMaxWidth,
      screenW - 2 * leadingActionWidth,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
        leadingWidth: leadingActionWidth,
        titleSpacing: 0,
        centerTitle: true,
        actions: [
          SizedBox(width: leadingActionWidth, height: 48),
        ],
        title: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: searchBarMaxW),
          child: SearchBarWidget(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: _submittedQuery.isEmpty &&
                (widget.initialQuery == null || widget.initialQuery!.isEmpty),
            hintText: kStorefrontSearchHint,
            filledCapsule: true,
            onChanged: (v) {
              setState(() {});
              if (v.trim().isEmpty) {
                _suggestionDebounce?.cancel();
                ref.read(searchSuggestionsProvider.notifier).clear();
                setState(() {});
                return;
              }
              _scheduleSuggestionFetch(v);
            },
            onSubmitted: _onSubmitted,
            onClear: _clearAll,
          ),
        ),
      ),
      body: _SearchBodyWrapper(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showSuggestions)
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: searchBarMaxW),
                child: SearchSuggestionsList(
                  query: typedForSuggestions,
                  suggestions: suggestionState.suggestions,
                  loading: suggestionState.loading || waitingDebounced,
                  errorMessage: suggestionState.errorMessage,
                  onSuggestionTap: _onSuggestionTap,
                ),
              ),
            ),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                if (_submittedQuery.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        Icons.search,
                        size: 56,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Find products',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Type to see suggestions, then press search on the keyboard '
                        'for full results. Not case-sensitive.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }

                if (products.isEmpty) {
                  return PageRefreshableBody(
                    onRefresh: () => _refresh(ref),
                    child: PageEmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No products found',
                      subtitle:
                          'Nothing matches "$_submittedQuery". Try different keywords.',
                      action: OutlinedButton(
                        onPressed: _clearAll,
                        child: const Text('Clear search'),
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = catalogGridCrossAxisCount(width);
                    final spacing = catalogGridSpacing(width);
                    final horizontalPadding = catalogHorizontalPadding(context);
                    final aspectRatio = catalogGridChildAspectRatio(width);
                    final cardWidth =
                        (width - horizontalPadding * 2 - (crossAxisCount - 1) * spacing) /
                            crossAxisCount;

                    int? lineQty(String productId) {
                      for (final e in cart?.items ?? []) {
                        if (e.productId == productId) return e.quantity;
                      }
                      return null;
                    }

                    return RefreshIndicator(
                      onRefresh: () => _refresh(ref),
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(horizontalPadding),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: aspectRatio,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
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
                              ref
                                  .read(wishlistControllerProvider.notifier)
                                  .toggle(product.id);
                            },
                            isInCart: inCart,
                            cartLineQuantity: lineQty(product.id),
                            onUpdateCartQuantity: (q) async {
                              await ref
                                  .read(cartControllerProvider.notifier)
                                  .updateQuantity(
                                    productId: product.id,
                                    quantity: q,
                                  );
                            },
                            onRemoveFromCart: () async {
                              await ref
                                  .read(cartControllerProvider.notifier)
                                  .removeItem(productId: product.id);
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
                      ),
                    );
                  },
                );
              },
              loading: () {
                if (_submittedQuery.isEmpty) {
                  return const SizedBox.shrink();
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return PageLoadingGrid(
                      crossAxisCount: catalogGridCrossAxisCount(width),
                      childAspectRatio: catalogGridChildAspectRatio(width),
                    );
                  },
                );
              },
              error: (error, _) => PageRefreshableBody(
                onRefresh: () => _refresh(ref),
                child: PageErrorState(
                  title: 'Search failed',
                  message:
                      'Check your connection and try again.\n${error.toString()}',
                  onRetry: () {
                    ref.invalidate(productListProvider(_listQuery));
                    ref.read(storefrontCatalogRevisionProvider.notifier).bump();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _SearchBodyWrapper extends StatelessWidget {
  const _SearchBodyWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return WebMaxWidthCenter(child: child);
  }
}
