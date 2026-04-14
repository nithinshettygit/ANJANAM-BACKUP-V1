import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/wishlist_heart_sizes.dart';
import 'home_layout_metrics.dart';
import '../../features/catalog/domain/entities/product.dart';
import '../utils/price_formatter.dart';
import '../utils/product_availability.dart';
import '../utils/product_price_display.dart';
import 'app_network_image.dart';
import 'product_image.dart';
import 'star_rating_display.dart';
import 'storefront_wishlist_chip.dart';
import 'subtle_scale_on_pointer.dart';

/// Small / grid product card: **1:1** image, title, price, rating, wishlist.
class HomeProductDiscoveryCard extends StatefulWidget {
  const HomeProductDiscoveryCard({
    super.key,
    required this.product,
    required this.width,
    required this.height,
    this.onTap,
    this.isWishlisted = false,
    this.onToggleWishlist,
    this.wishlistHeartSize,
    this.wishlistChipExtent,
  });

  final Product product;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool isWishlisted;
  final VoidCallback? onToggleWishlist;
  /// When null, uses [WishlistHeartSizes.imageOverlayChip].
  final double? wishlistHeartSize;
  /// Saffron circle size; when null, **36** (product details rails).
  final double? wishlistChipExtent;

  @override
  State<HomeProductDiscoveryCard> createState() => _HomeProductDiscoveryCardState();
}

class _HomeProductDiscoveryCardState extends State<HomeProductDiscoveryCard> {
  static const double _imageRadius = 12;
  bool _webHover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heartSize = widget.wishlistHeartSize ?? WishlistHeartSizes.imageOverlayChip;
    final chipExtent = widget.wishlistChipExtent ?? 36;
    final product = widget.product;
    final width = widget.width;
    final height = widget.height;
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const metaReserve = 92.0;
    final imageSide = math.min(width, height - metaReserve).clamp(72.0, width);
    final mem = imageMemCacheExtent(imageSide, dpr);
    final outOfStock = productIsOutOfStock(product);
    final pricing = ProductPriceDisplay.forProduct(
      product,
      hidePromoWhenOutOfStock: true,
      outOfStock: outOfStock,
    );

    const radius = 12.0;
    final webHoverLift = kIsWeb && _webHover && widget.onTap != null;
    final core = SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        elevation: webHoverLift ? 8 : 2,
        shadowColor: Colors.black.withValues(alpha: webHoverLift ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: widget.onTap,
          mouseCursor: kIsWeb && widget.onTap != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          borderRadius: BorderRadius.circular(radius),
            child: Ink(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: AppColors.borderSubtle.withValues(alpha: 0.85),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_imageRadius),
                    ),
                    child: ColoredBox(
                      color: Theme.of(context).cardColor,
                      child: SizedBox(
                        width: width,
                        height: imageSide,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: imageSide,
                            height: imageSide,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Opacity(
                                  opacity: outOfStock ? 0.5 : 1,
                                  child: ProductImage(
                                    imageUrl: imageUrl,
                                    borderRadius: BorderRadius.zero,
                                    memCacheWidth: mem,
                                    memCacheHeight: mem,
                                  ),
                                ),
                                if (widget.onToggleWishlist != null)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: StorefrontWishlistChip(
                                      extent: chipExtent,
                                      iconSize: heartSize,
                                      isWishlisted: widget.isWishlisted,
                                      onTap: widget.onToggleWishlist,
                                    ),
                                  ),
                                if (outOfStock)
                                  Positioned(
                                    left: 6,
                                    bottom: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.errorRed.withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Out of stock',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
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
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compactMeta = constraints.maxHeight < 90;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.title,
                                maxLines: compactMeta ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: HomeLayoutMetrics.homeProductTitleLineHeight(context),
                                      fontSize: HomeLayoutMetrics.homeProductTitleFontSize(context),
                                    ),
                              ),
                              const Spacer(),
                              if (!compactMeta &&
                                  product.averageRating != null &&
                                  product.totalReviews > 0) ...[
                                Row(
                                  children: [
                                    StarRatingDisplay(
                                      rating: product.averageRating!.round().clamp(1, 5),
                                      size: 12,
                                      color: AppColors.deepGold,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${product.averageRating!.toStringAsFixed(1)} (${product.totalReviews})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                              ],
                              if (pricing.showPromo)
                                Text(
                                  formatRupeeCompact(pricing.mrp!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                ),
                              Text(
                                formatRupeeCompact(pricing.salePrice),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppColors.priceText,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );

    final wrapped = kIsWeb
        ? core
        : SubtleScaleOnPointer(child: core);

    if (kIsWeb && widget.onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _webHover = true),
        onExit: (_) => setState(() => _webHover = false),
        child: AnimatedScale(
          scale: _webHover ? 1.015 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: wrapped,
        ),
      );
    }
    return wrapped;
  }
}
