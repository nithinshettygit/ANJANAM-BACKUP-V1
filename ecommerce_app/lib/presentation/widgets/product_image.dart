import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Reusable product image for list/grid cards.
///
/// Uses a square [AspectRatio] and [BoxFit.cover] so thumbnails stay consistent
/// without stretching. Fills the ratio box directly (no [LayoutBuilder]) so
/// layout stays stable under horizontal lists and [Stack]s.
class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final double aspectRatio;
  final BorderRadius borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 1,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final u = imageUrl?.trim();
    if (u == null || u.isEmpty) {
      return _fallbackBox(context);
    }

    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (_, __) => _placeholderBox(context),
      errorWidget: (_, __, ___) => _fallbackBox(context),
    );
  }

  Widget _placeholderBox(BuildContext context) {
    return const ColoredBox(color: Colors.black12);
  }

  Widget _fallbackBox(BuildContext context) {
    return ColoredBox(
      color: Colors.black12,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
