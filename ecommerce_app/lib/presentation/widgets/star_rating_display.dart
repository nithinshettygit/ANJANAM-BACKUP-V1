import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Filled stars for an integer [rating] in 1–5.
class StarRatingDisplay extends StatelessWidget {
  final int rating;
  final double size;
  final Color? color;
  /// Horizontal gap between star icons (can be 0 for a tight cluster).
  final double gap;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 18,
    this.color,
    this.gap = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brandGold;
    final r = rating.clamp(0, 5);
    final emptyColor = c.withValues(alpha: 0.38);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Icon(
            i < r ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: i < r ? c : emptyColor,
          ),
        ],
      ],
    );
  }
}
