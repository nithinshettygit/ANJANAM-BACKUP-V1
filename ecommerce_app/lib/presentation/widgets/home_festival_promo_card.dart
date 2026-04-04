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
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.brandSaffron.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'FESTIVE PICK',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            fontSize: 10,
                          ),
                    ),
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
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Explore',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.brandSaffronDeep,
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
