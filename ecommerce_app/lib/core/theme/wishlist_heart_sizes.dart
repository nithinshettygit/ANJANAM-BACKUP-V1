/// Wishlist heart icon sizes app-wide. Outer circles / chip bounds stay fixed in widgets.
abstract final class WishlistHeartSizes {
  /// Gallery overlay heart size (chip diameter is [productGalleryChipExtent]).
  static const double productGallery = 30;

  /// Product image gallery wishlist disc diameter (matches prior [CircleAvatar] radius 20).
  static const double productGalleryChipExtent = 40;

  /// Default heart on image cards when [wishlistHeartSize] is omitted (36px chip).
  static const double imageOverlayChip = 26;

  /// Home shelves: scale wishlist chip + heart from the product image width (1:1 side or 4:5 width).
  static ({double chipExtent, double heartSize}) homeShelfWishlistForImageWidth(
    double imageWidth,
  ) {
    final w = imageWidth.isFinite && imageWidth > 0 ? imageWidth : 160.0;
    final chip = (w * 0.192).clamp(30.0, 44.0);
    final heart = (chip * 0.61).clamp(19.0, 26.0);
    return (chipExtent: chip, heartSize: heart);
  }

  /// Catalog [ProductCard] wishlist: one size for all column widths (avoids uneven look at ~172px breakpoint).
  static const double gridCardChipExtent = 32;
  static const double gridCardHeart = 17;

  /// App bar wishlist entry ([IconButton] + [Badge]).
  static const double appBar = 28;

  /// Profile Wishlist quick action (inside 34x34 tinted box).
  static const double profileQuickAction = 24;

  /// Wishlist empty states ([PageEmptyState] leading icon).
  static const double emptyStateHero = 56;
}
