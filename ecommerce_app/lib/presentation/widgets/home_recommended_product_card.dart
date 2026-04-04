import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/cart/state/cart_controller.dart';
import '../../features/catalog/domain/entities/product.dart';
import '../utils/cart_feedback_snackbar.dart';
import '../utils/price_formatter.dart';
import '../utils/product_availability.dart';
import '../utils/product_price_display.dart';
import 'app_network_image.dart';
import 'home_layout_metrics.dart';
import 'product_image.dart';
import 'subtle_scale_on_pointer.dart';

/// Medium rail card: square image, title, price, Add to cart.
class HomeRecommendedProductCard extends ConsumerWidget {
  const HomeRecommendedProductCard({
    super.key,
    required this.product,
    required this.width,
    required this.totalHeight,
    this.onOpenDetails,
  });

  final Product product;
  final double width;
  final double totalHeight;
  final VoidCallback? onOpenDetails;

  static const double _radius = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = imageMemCacheExtent(width, dpr);
    final outOfStock = productIsOutOfStock(product);
    final pricing = ProductPriceDisplay.forProduct(
      product,
      hidePromoWhenOutOfStock: true,
      outOfStock: outOfStock,
    );

    Future<void> onAddToCart() async {
      if (outOfStock) return;
      await ref.read(cartControllerProvider.notifier).addItem(
            productId: product.id,
            quantity: 1,
          );
      if (!context.mounted) return;
      showAddedToCartSnackBar(ref, context, productTitle: product.title);
    }

    return SubtleScaleOnPointer(
      child: SizedBox(
        width: width,
        height: totalHeight,
        child: Material(
          color: AppColors.surfaceCard,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(_radius),
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
                      height: width,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Opacity(
                            opacity: outOfStock ? 0.5 : 1,
                            child: ProductImage(
                              imageUrl: imageUrl,
                              borderRadius: BorderRadius.zero,
                              memCacheWidth: memW,
                              memCacheHeight: memW,
                            ),
                          ),
                          if (outOfStock)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.errorRed.withValues(alpha: 0.9),
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
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HomeLayoutMetrics.homeRecommendedRailTitleStyle(
                            context,
                            Theme.of(context).textTheme,
                          ),
                        ),
                        const Spacer(),
                        if (pricing.showPromo)
                          Text(
                            formatRupeeCompact(pricing.mrp!),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        Text(
                          formatRupeeCompact(pricing.salePrice),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.brandSaffron,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: FilledButton(
                            onPressed: outOfStock ? null : onAddToCart,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Add to cart'),
                          ),
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
