import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Decode dimension in pixels for [memCacheWidth] / [memCacheHeight].
/// Clamps to avoid tiny allocations (device gralloc issues) and huge textures.
int? imageMemCacheExtent(double logicalPx, double devicePixelRatio) {
  if (!logicalPx.isFinite || logicalPx < 1) return null;
  final p = (logicalPx * devicePixelRatio).round();
  if (p < 32) return null;
  return math.min(p, 2048);
}

class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  /// Decode/cache at this width in **pixels** (device pixels). Reduces memory for list thumbnails.
  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _fallback();
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _fallback(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.black12,
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: Colors.black12,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}

