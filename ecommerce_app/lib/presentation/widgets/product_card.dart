import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/core/theme/wishlist_heart_sizes.dart';
import 'package:flutter/foundation.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';
import 'package:ecommerce_app/presentation/utils/product_availability.dart';
import 'package:ecommerce_app/presentation/utils/product_price_display.dart';
import 'package:ecommerce_app/presentation/widgets/product_image.dart';
import 'package:ecommerce_app/presentation/widgets/product_quantity_stepper.dart';
import 'package:ecommerce_app/presentation/widgets/star_rating_display.dart';
import 'package:ecommerce_app/presentation/widgets/storefront_wishlist_chip.dart';
import 'package:flutter/material.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback? onTap;
  /// Quantity to add when not yet in cart; ignored when [cartLineQuantity] is set.
  final Future<void> Function(int quantity)? onAddToCart;
  final Future<void> Function(int quantity)? onBuyNow;
  final VoidCallback? onToggleWishlist;
  final bool isWishlisted;
  final bool isInCart;
  final VoidCallback? onGoToCart;
  /// When set, stepper edits this cart line (and +/- update the cart).
  final int? cartLineQuantity;
  final Future<void> Function(int newQuantity)? onUpdateCartQuantity;
  final Future<void> Function()? onRemoveFromCart;
  final double width;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.onBuyNow,
    this.onToggleWishlist,
    this.isWishlisted = false,
    this.isInCart = false,
    this.onGoToCart,
    this.cartLineQuantity,
    this.onUpdateCartQuantity,
    this.onRemoveFromCart,
    this.width = 180,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _localQty = 1;
  bool _webHover = false;

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _localQty = 1;
    }
  }

  int get _max => maxSelectableQuantity(widget.product);

  int get _shownQty => widget.cartLineQuantity ?? _localQty;

  Future<void> _setQuantity(int next) async {
    final clamped = next.clamp(0, _max);
    if (clamped <= 0) {
      if (widget.onRemoveFromCart != null) {
        await widget.onRemoveFromCart!.call();
      }
      return;
    }
    if (widget.cartLineQuantity != null) {
      await widget.onUpdateCartQuantity?.call(clamped);
    } else {
      setState(() => _localQty = clamped);
    }
  }

  Future<void> _onAddPressed() async {
    if (widget.isInCart) {
      widget.onGoToCart?.call();
      return;
    }
    if (widget.onAddToCart == null) return;
    await widget.onAddToCart!.call(_shownQty);
  }

  Future<void> _onBuyPressed() async {
    if (widget.onBuyNow == null) return;
    await widget.onBuyNow!.call(_shownQty);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (widget.width * dpr).round().clamp(1, 2048);
    final outOfStock = productIsOutOfStock(product);
    final pricing = ProductPriceDisplay.forProduct(
      product,
      hidePromoWhenOutOfStock: true,
      outOfStock: outOfStock,
    );
    final lowStock = productIsLowStock(product);
    final stockBanner =
        (lowStock && !outOfStock) ? productStockBannerText(product) : null;
    final blockBuy = outOfStock;
    final blockAddUnlessInCart = outOfStock && !widget.isInCart;

    // Grid tiles can be ~160px wide with a tight aspect ratio; keep the lower
    // block from overflowing the Expanded region (~210px).
    final compact = widget.width < 172;
    final bodyPadding =
        compact ? const EdgeInsets.fromLTRB(6, 4, 6, 4) : const EdgeInsets.all(6);
    final gapSm = compact ? 2.0 : 4.0;
    final btnHeight = compact ? 30.0 : 32.0;
    final starSize = compact ? 12.0 : 14.0;

    final card = SizedBox(
      width: widget.width,
      child: Card(
        color: Theme.of(context).cardColor,
        clipBehavior: Clip.antiAlias,
        elevation: kIsWeb && _webHover ? 10 : 2,
        shadowColor: Colors.black.withValues(alpha: kIsWeb && _webHover ? 0.14 : 0.08),
        child: InkWell(
          onTap: widget.onTap,
          mouseCursor:
              kIsWeb && widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: widget.width,
                height: widget.width,
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Opacity(
                      opacity: outOfStock ? 0.45 : 1,
                      child: ProductImage(
                        imageUrl: imageUrl,
                        borderRadius: BorderRadius.zero,
                        memCacheWidth: memW,
                        memCacheHeight: memW,
                      ),
                    ),
                  if (outOfStock)
                    Positioned(
                      left: 6,
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.errorRed.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'OUT OF STOCK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  if (!outOfStock && pricing.showPromo)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.marigoldOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pricing.discountPercent}% OFF',
                          style: const TextStyle(
                            color: AppColors.charcoalBlack,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: bodyPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.forestGreen.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (product.category ?? 'General').toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.forestGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          StorefrontWishlistChip(
                            extent: WishlistHeartSizes.gridCardChipExtent,
                            iconSize: WishlistHeartSizes.gridCardHeart,
                            isWishlisted: widget.isWishlisted,
                            onTap: widget.onToggleWishlist,
                          ),
                        ],
                      ),
                      // Books (and similar) often show rating + promo + stock + stepper at once;
                      // grid height is fixed — scale this block down when it would overflow.
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: widget.width - bodyPadding.horizontal,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: gapSm),
                                  Text(
                                    product.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  if (product.averageRating != null &&
                                      product.totalReviews > 0) ...[
                                    SizedBox(height: gapSm),
                                    Row(
                                      children: [
                                        StarRatingDisplay(
                                          rating:
                                              product.averageRating!.round().clamp(1, 5),
                                          size: starSize,
                                          color: AppColors.deepGold,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${product.averageRating!.toStringAsFixed(1)} (${product.totalReviews})',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                                fontSize: compact ? 10 : null,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (pricing.showPromo)
                                    Text(
                                      formatRupeeCompact(pricing.mrp!),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            decoration: TextDecoration.lineThrough,
                                            fontSize: compact ? 11 : null,
                                          ),
                                    ),
                                  if (pricing.showPromo) SizedBox(height: compact ? 1 : 2),
                                  Text(
                                    formatRupeeCompact(pricing.salePrice),
                                    style: (compact
                                            ? Theme.of(context).textTheme.titleMedium
                                            : Theme.of(context).textTheme.titleLarge)
                                        ?.copyWith(
                                          color: AppColors.priceText,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  if (stockBanner != null) ...[
                                    SizedBox(height: compact ? 1 : 2),
                                    Text(
                                      stockBanner,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: AppColors.marigoldOrange,
                                                fontWeight: FontWeight.w700,
                                                fontSize: compact ? 10 : null,
                                              ),
                                    ),
                                  ],
                                  SizedBox(height: gapSm),
                                  if (!outOfStock)
                                    Center(
                                      child: ProductQuantityStepper(
                                        quantity: _shownQty.clamp(1, _max),
                                        minQuantity: 1,
                                        maxQuantity: _max,
                                        dense: true,
                                        allowZeroOnDecrement:
                                            widget.cartLineQuantity != null &&
                                                widget.onRemoveFromCart != null,
                                        onChanged: (q) {
                                          // ignore: discarded_futures
                                          _setQuantity(q);
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: 'Buy now',
                              child: SizedBox(
                                height: btnHeight,
                                child: Material(
                                  color: blockBuy
                                      ? Theme.of(context).disabledColor.withValues(alpha: 0.35)
                                      : AppColors.marigoldOrange,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    onTap: blockBuy || widget.onBuyNow == null
                                        ? null
                                        : () {
                                            // ignore: discarded_futures
                                            _onBuyPressed();
                                          },
                                    borderRadius: BorderRadius.circular(18),
                                    child: Icon(
                                      Icons.flash_on,
                                      size: 16,
                                      color: blockBuy
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.38)
                                          : AppColors.charcoalBlack,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Tooltip(
                              message: widget.isInCart ? 'Go to cart' : 'Add to cart',
                              child: SizedBox(
                                height: btnHeight,
                                child: Material(
                                  color: widget.isInCart
                                      ? AppColors.forestGreen.withValues(alpha: 0.85)
                                      : AppColors.deepGold,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    onTap: widget.isInCart
                                        ? widget.onGoToCart
                                        : blockAddUnlessInCart || widget.onAddToCart == null
                                            ? null
                                            : () {
                                                // ignore: discarded_futures
                                                _onAddPressed();
                                              },
                                    borderRadius: BorderRadius.circular(18),
                                    child: Icon(
                                      widget.isInCart
                                          ? Icons.shopping_cart_outlined
                                          : Icons.add_shopping_cart,
                                      size: 16,
                                      color: AppColors.charcoalBlack,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (kIsWeb && widget.onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _webHover = true),
        onExit: (_) => setState(() => _webHover = false),
        child: AnimatedScale(
          scale: _webHover ? 1.01 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: card,
        ),
      );
    }
    return card;
  }
}
