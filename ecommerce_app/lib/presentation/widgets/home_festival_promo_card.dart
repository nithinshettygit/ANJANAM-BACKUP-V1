import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/wishlist_heart_sizes.dart';
import '../../features/catalog/domain/entities/product.dart';
import 'app_network_image.dart';
import 'storefront_wishlist_chip.dart';
import 'subtle_scale_on_pointer.dart';

/// Wide banner-style card: hero image, gradient, compact Festival pick pill (top-left), title.
class HomeFestivalPromoCard extends StatelessWidget {
  const HomeFestivalPromoCard({
    super.key,
    required this.product,
    required this.width,
    required this.height,
    this.onExplore,
    this.isWishlisted = false,
    this.onToggleWishlist,
    this.wishlistHeartSize,
    this.wishlistChipExtent,
  });

  final Product product;
  final double width;
  final double height;
  final VoidCallback? onExplore;
  final bool isWishlisted;
  final VoidCallback? onToggleWishlist;
  /// When null, uses [WishlistHeartSizes.imageOverlayChip].
  final double? wishlistHeartSize;
  /// Saffron circle size; when null, **36**.
  final double? wishlistChipExtent;

  @override
  Widget build(BuildContext context) {
    final heartSize = wishlistHeartSize ?? WishlistHeartSizes.imageOverlayChip;
    final chipExtent = wishlistChipExtent ?? 36;
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = imageMemCacheExtent(width, dpr);
    final memH = imageMemCacheExtent(height, dpr);

    const radius = 16.0;

    return SubtleScaleOnPointer(
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: AppColors.surfaceCard,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onExplore,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(
                  imageUrl: imageUrl,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.zero,
                  memCacheWidth: memW,
                  memCacheHeight: memH,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.brandSaffron.withValues(alpha: 0.22),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onExplore,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          'Festival pick',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.brandSaffron,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 0.15,
                                height: 1.1,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (onToggleWishlist != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: StorefrontWishlistChip(
                      extent: chipExtent,
                      iconSize: heartSize,
                      isWishlisted: isWishlisted,
                      onTap: onToggleWishlist,
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.22,
                              fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) + 0.5,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                      ),
                    ],
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
