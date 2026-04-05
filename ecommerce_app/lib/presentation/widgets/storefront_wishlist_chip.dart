import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Circular wishlist control: white disc; outline heart in black, filled heart in red when saved.
///
/// Uses [InkWell] + [Center] for reliable glyph centering in the circle.
class StorefrontWishlistChip extends StatelessWidget {
  const StorefrontWishlistChip({
    super.key,
    required this.extent,
    required this.iconSize,
    required this.isWishlisted,
    this.onTap,
    this.tooltip,
  });

  final double extent;
  final double iconSize;
  final bool isWishlisted;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget chip = Material(
      color: AppColors.surfaceCard,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        splashColor: Colors.black.withValues(alpha: 0.08),
        highlightColor: Colors.black.withValues(alpha: 0.04),
        child: SizedBox.square(
          dimension: extent,
          child: Center(
            child: Icon(
              isWishlisted ? Icons.favorite : Icons.favorite_border,
              size: iconSize,
              color: isWishlisted ? AppColors.errorRed : AppColors.charcoalBlack,
            ),
          ),
        ),
      ),
    );

    final t = tooltip;
    if (t != null && t.isNotEmpty) {
      chip = Tooltip(message: t, child: chip);
    }

    return chip;
  }
}
