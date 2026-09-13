import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/wishlist_heart_sizes.dart';
import '../../features/cart/state/cart_controller.dart';
import '../../features/catalog/domain/entities/product.dart';
import '../utils/auth_issue_presenter.dart';
import '../utils/cart_feedback_snackbar.dart';
import '../utils/main_shell_navigation.dart';
import '../utils/price_formatter.dart';
import '../utils/product_availability.dart';
import '../utils/product_price_display.dart';
import 'app_network_image.dart';
import 'home_layout_metrics.dart';
import 'product_image.dart';
import 'star_rating_display.dart';
import 'storefront_wishlist_chip.dart';
import 'subtle_scale_on_pointer.dart';

/// Recommended rail card: **4:5** image, title (2 lines), stars, sale + strikethrough MRP, CTA.
class HomeRecommendedProductCard extends ConsumerWidget {
  const HomeRecommendedProductCard({
    super.key,
    required this.product,
    required this.width,
    required this.totalHeight,
    this.onOpenDetails,
    this.isWishlisted = false,
    this.onToggleWishlist,
    this.wishlistHeartSize,
    this.wishlistChipExtent,
  });

  final Product product;
  final double width;
  final double totalHeight;
  final VoidCallback? onOpenDetails;
  final bool isWishlisted;
  final VoidCallback? onToggleWishlist;
  /// When null, uses [WishlistHeartSizes.imageOverlayChip].
  final double? wishlistHeartSize;
  /// Saffron circle size; when null, **36**.
  final double? wishlistChipExtent;

  static const double _radius = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heartSize = wishlistHeartSize ?? WishlistHeartSizes.imageOverlayChip;
    final chipExtent = wishlistChipExtent ?? 36;
    final inCart = ref.watch(
      cartControllerProvider.select(
        (asyncCart) =>
            asyncCart.valueOrNull?.items.any((e) => e.productId == product.id) ??
            false,
      ),
    );
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = imageMemCacheExtent(width, dpr);
    final imgH = HomeLayoutMetrics.recommendedImageHeight(width);
    final memH = imageMemCacheExtent(imgH, dpr);
    final outOfStock = productIsOutOfStock(product);
    final pricing = ProductPriceDisplay.forProduct(
      product,
      hidePromoWhenOutOfStock: true,
      outOfStock: outOfStock,
    );
    final theme = Theme.of(context);
    final titleStyle = HomeLayoutMetrics.homeRecommendedRailTitleStyle(
      context,
      theme.textTheme,
    );

    Future<void> onAddToCart() async {
      if (outOfStock) return;
      try {
        await ref.read(cartControllerProvider.notifier).addItem(
              productId: product.id,
              quantity: 1,
            );
        if (!context.mounted) return;
        showAddedToCartSnackBar(ref, context, productTitle: product.title);
      } on AuthException catch (_) {
        if (!context.mounted) return;
        await presentSignInToManageCartDialog(context);
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
    }

    return SubtleScaleOnPointer(
      child: SizedBox(
        width: width,
        height: totalHeight,
        child: Material(
          color: AppColors.surfaceCard,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.09),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
            side: BorderSide(
              color: AppColors.borderSubtle.withValues(alpha: 0.9),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: onOpenDetails,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_radius),
                    ),
                    child: SizedBox(
                      width: width,
                      height: imgH,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Opacity(
                            opacity: outOfStock ? 0.5 : 1,
                            child: ProductImage(
                              imageUrl: imageUrl,
                              aspectRatio: width / imgH,
                              borderRadius: BorderRadius.zero,
                              memCacheWidth: memW,
                              memCacheHeight: memH,
                            ),
                          ),
                          if (onToggleWishlist != null)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: StorefrontWishlistChip(
                                extent: chipExtent,
                                iconSize: heartSize,
                                isWishlisted: isWishlisted,
                                onTap: onToggleWishlist,
                              ),
                            ),
                          if (outOfStock)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.errorRed.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Out of stock',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                            if (product.averageRating != null &&
                                product.averageRating! > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  StarRatingDisplay(
                                    rating: product.averageRating!.round().clamp(1, 5),
                                    size: 15,
                                    gap: 1,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      product.totalReviews > 0
                                          ? '${product.averageRating!.toStringAsFixed(1)} (${product.totalReviews})'
                                          : product.averageRating!.toStringAsFixed(1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.15,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Flexible(
                                  child: Text(
                                    formatRupeeCompact(pricing.salePrice),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: AppColors.priceText,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (pricing.showPromo && pricing.mrp != null) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      formatRupeeCompact(pricing.mrp!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 34,
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: outOfStock
                                    ? null
                                    : inCart
                                        ? () => navigateToCartPage(ref, context)
                                        : onAddToCart,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  backgroundColor: inCart
                                      ? AppColors.forestGreen
                                      : AppColors.brandSaffron,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      AppColors.textSecondary.withValues(alpha: 0.35),
                                  disabledForegroundColor: Colors.white.withValues(
                                    alpha: 0.75,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                    color: Colors.white,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  inCart
                                      ? AppLocalizations.of(context).goToCart
                                      : AppLocalizations.of(context).addToCart,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
