import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Filled stars for an integer [rating] in 1–5.
class StarRatingDisplay extends StatelessWidget {
  final int rating;
  final double size;
  final Color? color;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brandGold;
    final r = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < r ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: c,
        );
      }),
    );
  }
}
