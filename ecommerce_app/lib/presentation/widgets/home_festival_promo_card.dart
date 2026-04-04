import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/catalog/domain/entities/product.dart';
import 'app_network_image.dart';
import 'subtle_scale_on_pointer.dart';

/// Wide banner-style card: hero image, gradient, title, Explore CTA.
class HomeFestivalPromoCard extends StatelessWidget {
  const HomeFestivalPromoCard({
    super.key,
    required this.product,
    required this.width,
    required this.height,
    this.onExplore,
  });

  final Product product;
  final double width;
  final double height;
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = imageMemCacheExtent(width, dpr);
    final memH = imageMemCacheExtent(height, dpr);

    const radius = 12.0;

    return SubtleScaleOnPointer(
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: AppColors.surfaceCard,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
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
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
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
                              height: 1.2,
                              shadows: const [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Explore',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.brandSaffron,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
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
