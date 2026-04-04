import 'package:ecommerce_app/core/layout/storefront_web_layout.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_products_provider.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_provider.dart';
import 'package:ecommerce_app/presentation/utils/buy_now_navigation.dart';
import 'package:ecommerce_app/presentation/utils/cart_feedback_snackbar.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/utils/storefront_product_navigation.dart';
import 'package:ecommerce_app/presentation/widgets/product_card.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistState = ref.watch(wishlistControllerProvider);
    if (wishlistState.isLoading && !wishlistState.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: const PageLoading(message: 'Loading wishlist...'),
      );
    }
    if (wishlistState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: PageErrorState(
          message: 'Could not load wishlist: ${wishlistState.error}',
          onRetry: () => ref.invalidate(wishlistControllerProvider),
        ),
      );
    }

    final wishlistIds = wishlistState.value ?? {};
    final cart = ref.watch(
      cartControllerProvider.select((async) => async.value),
    );

    if (wishlistIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: const PageEmptyState(
          icon: Icons.favorite_border,
          title: 'Your wishlist is empty',
          subtitle: 'Tap heart icons on products to save them.',
        ),
      );
    }

    final productsAsync = ref.watch(wishlistProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: productsAsync.when(
        data: (wished) {
          if (wished.isEmpty) {
            return const PageEmptyState(
              icon: Icons.favorite_border,
              title: 'Your wishlist is empty',
              subtitle: 'Saved products may be unavailable. Try refreshing.',
            );
          }

          int? lineQty(String productId) {
            for (final e in cart?.items ?? []) {
              if (e.productId == productId) return e.quantity;
            }
            return null;
          }

          final grid = RefreshIndicator(
            onRefresh: () async {
              ref.read(storefrontCatalogRevisionProvider.notifier).bump();
              await ref.read(wishlistProductsProvider.future);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = catalogGridCrossAxisCount(width);
                final spacing = catalogGridSpacing(width);
                final hPad = catalogHorizontalPadding(context);
                final aspectRatio = catalogGridChildAspectRatio(width);
                final cardWidth =
                    (width - hPad * 2 - (crossAxisCount - 1) * spacing) / crossAxisCount;
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(hPad),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: wished.length,
                  itemBuilder: (context, index) {
                    final product = wished[index];
                    final inCart =
                        cart?.items.any((e) => e.productId == product.id) ?? false;
                    return ProductCard(
                      product: product,
                      width: cardWidth,
                      isWishlisted: true,
                      onToggleWishlist: () =>
                          ref.read(wishlistControllerProvider.notifier).toggle(product.id),
                      onTap: () => navigateToStorefrontProductDetails(
                        context,
                        ref,
                        product.id,
                      ),
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
                        await ref.read(cartControllerProvider.notifier).removeItem(
                              productId: product.id,
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
                );
              },
            ),
          );
          return kIsWeb ? WebMaxWidthCenter(child: grid) : grid;
        },
        loading: () => const PageLoading(message: 'Loading wishlist...'),
        error: (error, _) => PageErrorState(
          message: 'Failed to load wishlist: $error',
          onRetry: () => ref.invalidate(wishlistProductsProvider),
        ),
      ),
    );
  }
}
