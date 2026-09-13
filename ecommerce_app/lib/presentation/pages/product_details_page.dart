import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/layout/storefront_web_layout.dart';
import 'package:ecommerce_app/features/catalog/state/product_list_providers.dart';
import 'package:ecommerce_app/features/catalog/domain/product_sort_option.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product_variant.dart';
import 'package:ecommerce_app/features/product_details/state/product_details_providers.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_provider.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/core/theme/wishlist_heart_sizes.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';
import 'package:ecommerce_app/presentation/utils/storefront_title_styles.dart';
import 'package:ecommerce_app/presentation/utils/product_price_display.dart';
import 'package:ecommerce_app/presentation/utils/buy_now_navigation.dart';
import 'package:ecommerce_app/presentation/utils/auth_issue_presenter.dart';
import 'package:ecommerce_app/presentation/utils/cart_feedback_snackbar.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/utils/product_availability.dart';
import 'package:ecommerce_app/presentation/utils/storefront_product_navigation.dart';
import 'package:ecommerce_app/core/web/web_seo.dart';
import 'package:ecommerce_app/presentation/utils/universal_share.dart';
import 'package:ecommerce_app/presentation/widgets/home_product_discovery_card.dart';
import 'package:ecommerce_app/presentation/widgets/product_image_carousel.dart';
import 'package:ecommerce_app/presentation/widgets/storefront_wishlist_chip.dart';
import 'package:ecommerce_app/presentation/widgets/product_quantity_stepper.dart';
import 'package:ecommerce_app/presentation/widgets/web_horizontal_rail_list.dart';
import 'package:ecommerce_app/features/product_questions/widgets/product_questions_section.dart';
import 'package:ecommerce_app/presentation/widgets/product_reviews_section.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:ecommerce_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _navigateWebProductVisitorToHome(BuildContext context) {
  Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
}

PreferredSizeWidget _productDetailsAppBar(
  BuildContext context, {
  List<Widget>? actions,
}) {
  final theme = Theme.of(context);
  final titleStyle = theme.appBarTheme.titleTextStyle ??
      theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600);
  // Shared product links on web open this page alone — no back stack; offer home.
  final webDirectProductVisit = kIsWeb && !Navigator.of(context).canPop();
  return AppBar(
    centerTitle: true,
    titleSpacing: 0,
    leadingWidth: 48,
    automaticallyImplyLeading: !webDirectProductVisit,
    leading: webDirectProductVisit
        ? IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Go to store home',
            onPressed: () => _navigateWebProductVisitorToHome(context),
          )
        : null,
    title: Text(
      'Product Details',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: titleStyle,
    ),
    actions: actions,
  );
}

class ProductDetailsPage extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailsPage({
    super.key,
    required this.productId,
  });

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int _pendingQty = 1;
  /// When [null], [Product.defaultVariant] is used for multi-SKU products.
  String? _selectedVariantId;

  String? _resolveShareImageUrl(Product product, ProductVariant? sv, Product displayProduct) {
    final variantImage = sv?.imageUrl.trim();
    if (variantImage != null && variantImage.isNotEmpty) return variantImage;
    for (final url in displayProduct.imageUrls) {
      final t = url.trim();
      if (t.isNotEmpty) return t;
    }
    for (final url in product.imageUrls) {
      final t = url.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  Future<void> _shareProductFrom(
    BuildContext triggerContext,
    Product product,
    ProductPriceDisplay pricing, {
    String? heroImageUrl,
  }) async {
    final box = triggerContext.findRenderObject() as RenderBox?;
    Rect? origin;
    if (box != null && box.hasSize) {
      origin = Rect.fromPoints(
        box.localToGlobal(Offset.zero),
        box.localToGlobal(Offset(box.size.width, box.size.height)),
      );
    }
    try {
      await showUniversalShareSheet(
        context,
        payload: UniversalSharePayload(
          contentType: ShareContentType.product,
          idOrSlug: product.id,
          title: product.title,
          description: formatRupee(pricing.salePrice),
          imageUrl: heroImageUrl ??
              (product.imageUrls.isNotEmpty ? product.imageUrls.first : null),
        ),
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Web visitors who opened a shared `/product/...` link (no in-app back stack).
  Widget _webStoreEngagementBanner(BuildContext context) {
    return Material(
      color: AppColors.marigoldOrange.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _navigateWebProductVisitorToHome(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.storefront_outlined, color: AppColors.darkGreen, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore ANJANAM',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoalBlack,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'New here? Visit our home page for deals, categories, and more products.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.arrow_forward_rounded, color: AppColors.deepGold, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ProductDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _pendingQty = 1;
      _selectedVariantId = null;
    }
  }

  ProductVariant? _selectedVariant(Product product) {
    if (!product.hasVariants) return null;
    final id = _selectedVariantId;
    if (id != null) {
      for (final v in product.variants) {
        if (v.id == id) return v;
      }
    }
    return product.defaultVariant;
  }

  Product _displayProduct(Product product, ProductVariant? sv) {
    if (sv == null) return product;
    final vi = sv.imageUrl.trim();
    final imgs = vi.isNotEmpty
        ? [vi, ...product.imageUrls.where((u) => u != vi)]
        : product.imageUrls;
    return product.copyWith(
      price: sv.price,
      availableStock: sv.sellableStock,
      inventoryCount: sv.stockQuantity,
      imageUrls: imgs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(productDetailsProvider(widget.productId));
    return detailAsync.when(
      data: (detail) {
        final product = detail.product;
        final sv = _selectedVariant(product);
        final displayProduct = _displayProduct(product, sv);
        final isWishlisted = ref.watch(wishlistProvider).contains(product.id);
        final cart = ref.watch(
          cartControllerProvider.select((async) => async.valueOrNull),
        );
        final inCart = cart?.items.any((e) {
              if (e.productId != product.id) return false;
              if (!product.hasVariants) return e.variantId == null;
              return e.variantId == sv?.id;
            }) ??
            false;
        final outOfStock = productIsOutOfStock(displayProduct);
        final localizations = AppLocalizations.of(context);
        final stockBanner = productStockBannerText(displayProduct, localizations);
        final shareImageUrl = _resolveShareImageUrl(product, sv, displayProduct);
        if (kIsWeb) {
          WebSeo.updateSharePage(
            title: '${product.title} — ANJANAM',
            description: product.description.isNotEmpty
                ? product.description
                : 'Shop ${product.title} on ANJANAM.',
            path: '/product/${product.id}',
            imageUrl: shareImageUrl,
            ogType: 'product',
          );
        }
        final pricing = ProductPriceDisplay.forProduct(
          product,
          hidePromoWhenOutOfStock: true,
          outOfStock: outOfStock,
          salePriceOverride: sv?.price,
        );
        final maxQ = maxSelectableQuantity(displayProduct);
        int? lineQty;
        for (final e in cart?.items ?? []) {
          if (e.productId != product.id) continue;
          if (product.hasVariants) {
            if (e.variantId == sv?.id) {
              lineQty = e.quantity;
              break;
            }
          } else if (e.variantId == null) {
            lineQty = e.quantity;
            break;
          }
        }
        final displayQty = (lineQty ?? _pendingQty).clamp(1, maxQ);

        Widget scrollBody() {
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(storefrontCatalogRevisionProvider.notifier).bump();
              await ref.read(productDetailsProvider(widget.productId).future);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useWide =
                    kIsWeb && constraints.maxWidth > StorefrontBreakpoints.twoColumnDetail;
                final galleryH = useWide
                    ? (constraints.maxWidth * 0.28).clamp(300.0, 420.0)
                    : 260.0;
                final padH = kIsWeb && useWide ? 28.0 : 16.0;
                final bottomPad = kIsWeb && useWide ? 140.0 : 120.0;

                final gallery = Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: ProductImageCarousel(
                        key: ValueKey<String>('${product.id}_${sv?.id ?? 'base'}'),
                        imageUrls: displayProduct.imageUrls,
                        height: galleryH,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    if (pricing.showPromo)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.marigoldOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pricing.discountPercent}% OFF',
                            style: const TextStyle(
                              color: AppColors.charcoalBlack,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: StorefrontWishlistChip(
                        extent: WishlistHeartSizes.productGalleryChipExtent,
                        iconSize: WishlistHeartSizes.productGallery,
                        isWishlisted: isWishlisted,
                        onTap: () =>
                            ref.read(wishlistControllerProvider.notifier).toggle(product.id),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Builder(
                        builder: (btnContext) => CircleAvatar(
                          backgroundColor: AppColors.brandSaffron,
                          radius: 20,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Share product',
                            style: IconButton.styleFrom(
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.center,
                              visualDensity: VisualDensity.standard,
                            ),
                            onPressed: () => _shareProductFrom(
                              btnContext,
                              product,
                              pricing,
                              heroImageUrl: shareImageUrl,
                            ),
                            icon: const Icon(
                              Icons.share_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                List<Widget> titlePriceBlocks() => [
                      Text(
                        product.title,
                        style: storefrontProductNameStyle(context),
                      ),
                      if (product.hasVariants) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Options',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        ...(() {
                          final byType = <String, List<ProductVariant>>{};
                          for (final option in product.variants) {
                            final key = option.variantType.trim().isEmpty
                                ? 'option'
                                : option.variantType.trim().toLowerCase();
                            byType.putIfAbsent(key, () => <ProductVariant>[]).add(option);
                          }
                          final widgets = <Widget>[];
                          for (final entry in byType.entries) {
                            final typeLabel = entry.key;
                            final typeOptions = entry.value;
                            if (widgets.isNotEmpty) {
                              widgets.add(const SizedBox(height: 10));
                            }
                            widgets.add(
                              Text(
                                typeLabel[0].toUpperCase() + typeLabel.substring(1),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            );
                            widgets.add(const SizedBox(height: 6));
                            widgets.add(
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final v in typeOptions)
                                    Builder(
                                      builder: (context) {
                                        final oosV = (v.sellableStock ?? 0) <= 0;
                                        final sel = sv?.id == v.id;
                                        return ChoiceChip(
                                          label: Text(
                                            oosV
                                                ? '${v.variantName} · ${localizations.outOfStock}'
                                                : v.variantName,
                                            style: TextStyle(
                                              fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                                            ),
                                          ),
                                          selected: sel,
                                          onSelected: oosV
                                              ? null
                                              : (_) => setState(() => _selectedVariantId = v.id),
                                          selectedColor: AppColors.marigoldOrange.withValues(alpha: 0.35),
                                          disabledColor:
                                              Theme.of(context).colorScheme.surfaceContainerHighest,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            );
                          }
                          return widgets;
                        })(),
                        if (sv != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                if (displayProduct.imageUrls.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      displayProduct.imageUrls.first,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 52,
                                        height: 52,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.image_not_supported_outlined, size: 18),
                                      ),
                                    ),
                                  ),
                                if (displayProduct.imageUrls.isNotEmpty) const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Selected: ${sv.variantType.trim().isNotEmpty ? '${sv.variantType}: ' : ''}${sv.variantName}',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatRupee(sv.price),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 8),
                      if (pricing.showPromo) ...[
                        Text(
                          'MRP',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          formatRupee(pricing.mrp!),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You pay',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.priceText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      Text(
                        formatRupee(pricing.salePrice),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.priceText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (product.category != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.forestGreen.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.category!,
                            style: storefrontHeroTitleStyle(context).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkGreen,
                            ),
                          ),
                        ),
                      ],
                      if (stockBanner != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: outOfStock
                                ? AppColors.errorRed.withValues(alpha: 0.12)
                                : AppColors.marigoldOrange.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: outOfStock
                                  ? AppColors.errorRed.withValues(alpha: 0.5)
                                  : AppColors.marigoldOrange.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            stockBanner,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color:
                                      outOfStock ? AppColors.errorRed : AppColors.charcoalBlack,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ];

                List<Widget> quantityBlock() => [
                      Row(
                        children: [
                          Text(
                            'Quantity',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          ProductQuantityStepper(
                            quantity: displayQty,
                            minQuantity: 1,
                            maxQuantity: maxQ,
                            allowZeroOnDecrement: lineQty != null,
                            onChanged: (q) async {
                              if (lineQty != null) {
                                if (q <= 0) {
                                  await ref.read(cartControllerProvider.notifier).removeItem(
                                        productId: product.id,
                                        variantId: sv?.id,
                                      );
                                } else {
                                  await ref.read(cartControllerProvider.notifier).updateQuantity(
                                        productId: product.id,
                                        variantId: sv?.id,
                                        quantity: q,
                                      );
                                }
                              } else {
                                setState(() => _pendingQty = q.clamp(1, maxQ));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ];

                final belowFold = <Widget>[
                  ProductReviewsSection(
                    product: product,
                    listMode: ProductReviewsListMode.embeddedPreview,
                  ),
                  const SizedBox(height: 16),
                  ProductQuestionsSection(
                    product: product,
                    listMode: ProductQuestionsListMode.embeddedPreview,
                  ),
                  const SizedBox(height: 16),
                  SimilarProductsSection(
                    currentProductId: product.id,
                    category: product.category,
                    title: product.title,
                    tags: product.tags,
                  ),
                  const SizedBox(height: 16),
                  YouAlsoLikeSection(currentProductId: product.id),
                ];

                final webDirectProductVisit = kIsWeb && !Navigator.of(context).canPop();
                final shippingWeight = sv?.shippingWeightKg ?? product.shippingWeightKg;
                final shippingDimensions = sv?.shippingDimensionsCm ?? product.shippingDimensionsCm;

                final top = <Widget>[
                  if (webDirectProductVisit) _webStoreEngagementBanner(context),
                  if (webDirectProductVisit) SizedBox(height: useWide ? 16 : 12),
                  if (useWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: gallery),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...titlePriceBlocks(),
                              if (!outOfStock) ...[
                                const SizedBox(height: 8),
                                ...quantityBlock(),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    gallery,
                    const SizedBox(height: 16),
                    ...titlePriceBlocks(),
                  ],
                  SizedBox(height: useWide ? 24 : 16),
                  Text(
                    product.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shipping details',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Weight: ${shippingWeight != null && shippingWeight > 0 ? '${shippingWeight.toStringAsFixed(3)} kg' : '—'}',
                          ),
                          Text(
                            'Package: ${(shippingDimensions != null && shippingDimensions.trim().isNotEmpty) ? '$shippingDimensions cm' : '—'}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!useWide) ...[
                    const SizedBox(height: 20),
                    if (!outOfStock) ...quantityBlock(),
                  ],
                  const SizedBox(height: 16),
                  ...belowFold,
                ];

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(padH, padH, padH, bottomPad),
                  children: top,
                );
              },
            ),
          );
        }

        final body = scrollBody();
        return Scaffold(
          appBar: _productDetailsAppBar(
            context,
            actions: [
              Builder(
                builder: (appBarBtnContext) => IconButton(
                  tooltip: 'Share product',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.brandSaffron,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => _shareProductFrom(
                    appBarBtnContext,
                    product,
                    pricing,
                    heroImageUrl: shareImageUrl,
                  ),
                ),
              ),
            ],
          ),
          body: kIsWeb
              ? WebMaxWidthCenter(
                  child: StorefrontWebTypography.wrapIfDesktop(context, body),
                )
              : body,
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: inCart ? AppColors.forestGreen : AppColors.deepGold,
                        ),
                        foregroundColor: inCart ? AppColors.forestGreen : AppColors.deepGold,
                      ),
                      onPressed: inCart
                          ? () => navigateToCartPage(ref, context)
                          : outOfStock
                              ? null
                              : () async {
                                  try {
                                    await ref.read(cartControllerProvider.notifier).addItem(
                                          productId: product.id,
                                          variantId: sv?.id,
                                          quantity: displayQty,
                                        );
                                    if (!context.mounted) return;
                                    showAddedToCartSnackBar(
                                      ref,
                                      context,
                                      productTitle: product.title,
                                    );
                                  } on AuthException catch (_) {
                                    if (!context.mounted) return;
                                    await presentSignInToManageCartDialog(context);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to add to cart: $e'),
                                        duration: const Duration(seconds: 4),
                                        behavior: SnackBarBehavior.fixed,
                                      ),
                                    );
                                  }
                                },
                      icon: Icon(
                        inCart ? Icons.shopping_cart_outlined : Icons.add_shopping_cart,
                      ),
                      label: Text(
                        inCart
                          ? AppLocalizations.of(context).goToCart
                          : outOfStock
                            ? AppLocalizations.of(context).outOfStock
                            : AppLocalizations.of(context).addToCart,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: outOfStock
                          ? null
                          : () => openBuyNowCheckout(
                                context,
                                ref,
                                productId: product.id,
                                variantId: sv?.id,
                                quantity: displayQty,
                              ),
                      icon: const Icon(Icons.flash_on),
                      label: Text(
                        outOfStock
                            ? AppLocalizations.of(context).unavailable
                            : AppLocalizations.of(context).buyNow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: _productDetailsAppBar(context),
        body: const PageLoading(message: 'Loading product...'),
      ),
      error: (error, _) => Scaffold(
        appBar: _productDetailsAppBar(context),
        body: PageRefreshableBody(
          onRefresh: () async {
            ref.read(storefrontCatalogRevisionProvider.notifier).bump();
            await ref.read(productDetailsProvider(widget.productId).future);
          },
          child: PageErrorState(
            title: 'Product unavailable',
            message:
                'We could not load this product. It may have been removed from the store, or there may be a temporary connection issue. Pull to refresh, or open My Orders to see items you already purchased.',
            onRetry: () {
              ref.invalidate(productDetailsProvider(widget.productId));
              ref.read(storefrontCatalogRevisionProvider.notifier).bump();
            },
          ),
        ),
      ),
    );
  }
}

/// Web: larger discovery cards; native: unchanged (160×270).
({double width, double height}) _similarProductsCardSize(BuildContext context) {
  if (!kIsWeb) {
    return (width: 160.0, height: 270.0);
  }
  final layoutW = StorefrontLayoutScope.layoutWidthOf(context);
  final width = (layoutW * 0.175).clamp(184.0, 232.0);
  return (width: width, height: width + 106.0);
}

Widget _similarProductsHorizontalScroller({
  required double listHeight,
  required int itemCount,
  required IndexedWidgetBuilder itemBuilder,
}) {
  final gap = kIsWeb ? 12.0 : 8.0;
  if (kIsWeb) {
    return WebHorizontalRailList(
      height: listHeight,
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(width: gap),
      itemBuilder: itemBuilder,
    );
  }
  return SizedBox(
    height: listHeight,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(width: gap),
      itemBuilder: itemBuilder,
    ),
  );
}

class SimilarProductsSection extends ConsumerWidget {
  const SimilarProductsSection({
    super.key,
    required this.currentProductId,
    required this.category,
    required this.title,
    required this.tags,
  });

  final String currentProductId;
  final String? category;
  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      similarProductsProvider(
        SimilarProductsQuery(
          currentProductId: currentProductId,
          category: category,
          title: title,
          tags: tags,
          limit: 8,
        ),
      ),
    );
    final wishlist = ref.watch(wishlistProvider);
    final card = _similarProductsCardSize(context);

    return async.when(
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Similar Products',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            _similarProductsHorizontalScroller(
              listHeight: card.height,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final wl = WishlistHeartSizes.homeShelfWishlistForImageWidth(card.width);
                return HomeProductDiscoveryCard(
                  product: product,
                  width: card.width,
                  height: card.height,
                  wishlistHeartSize: wl.heartSize,
                  wishlistChipExtent: wl.chipExtent,
                  isWishlisted: wishlist.contains(product.id),
                  onToggleWishlist: () {
                    ref.read(wishlistControllerProvider.notifier).toggle(product.id);
                  },
                  onTap: () => navigateToStorefrontProductDetails(
                    context,
                    ref,
                    product.id,
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Similar Products',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          _similarProductsHorizontalScroller(
            listHeight: card.height,
            itemCount: 5,
            itemBuilder: (context, _) => _SuggestionSkeletonCard(width: card.width),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class YouAlsoLikeSection extends ConsumerStatefulWidget {
  const YouAlsoLikeSection({
    super.key,
    required this.currentProductId,
  });

  final String currentProductId;

  @override
  ConsumerState<YouAlsoLikeSection> createState() => _YouAlsoLikeSectionState();
}

class _YouAlsoLikeSectionState extends ConsumerState<YouAlsoLikeSection> {
  static const int _pageSize = 8;
  final ScrollController _scrollController = ScrollController();
  final List<Product> _items = [];
  final Set<String> _seenIds = <String>{};
  bool _loading = false;
  bool _loadedInitial = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant YouAlsoLikeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentProductId != widget.currentProductId) {
      _items.clear();
      _seenIds.clear();
      _loading = false;
      _loadedInitial = false;
      _hasMore = true;
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || !_hasMore || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 260) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final page = await repo.fetchProducts(
        sort: ProductSortOption.newest,
        limit: _pageSize,
        offset: _items.length,
      );
      final before = _items.length;
      for (final p in page) {
        if (p.id == widget.currentProductId) continue;
        if (_seenIds.add(p.id)) {
          _items.add(p);
        }
      }
      _hasMore = page.length == _pageSize && _items.length > before;
    } catch (_) {
      _hasMore = false;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadedInitial = true;
        });
      }
    }
  }

  void _maybeLoadMoreFromScroll(ScrollMetrics m) {
    if (!kIsWeb || m.axis != Axis.horizontal) return;
    if (_loading || !_hasMore) return;
    if (m.pixels >= m.maxScrollExtent - 260) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);
    final card = _similarProductsCardSize(context);

    if (!_loadedInitial && _items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You also like',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          if (kIsWeb)
            _similarProductsHorizontalScroller(
              listHeight: card.height,
              itemCount: 5,
              itemBuilder: (_, __) => _SuggestionSkeletonCard(width: card.width),
            )
          else
            SizedBox(
              height: card.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) => _SuggestionSkeletonCard(width: card.width),
              ),
            ),
        ],
      );
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (kIsWeb) {
      final rail = _similarProductsHorizontalScroller(
        listHeight: card.height,
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return _SuggestionSkeletonCard(width: card.width);
          }
          final product = _items[index];
          final wl = WishlistHeartSizes.homeShelfWishlistForImageWidth(card.width);
          return HomeProductDiscoveryCard(
            product: product,
            width: card.width,
            height: card.height,
            wishlistHeartSize: wl.heartSize,
            wishlistChipExtent: wl.chipExtent,
            isWishlisted: wishlist.contains(product.id),
            onToggleWishlist: () {
              ref.read(wishlistControllerProvider.notifier).toggle(product.id);
            },
            onTap: () => navigateToStorefrontProductDetails(
              context,
              ref,
              product.id,
            ),
          );
        },
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You also like',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is! ScrollUpdateNotification) return false;
              _maybeLoadMoreFromScroll(n.metrics);
              return false;
            },
            child: rail,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You also like',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: card.height,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _items.length + (_loading ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return _SuggestionSkeletonCard(width: card.width);
              }
              final product = _items[index];
              final wl = WishlistHeartSizes.homeShelfWishlistForImageWidth(card.width);
              return HomeProductDiscoveryCard(
                product: product,
                width: card.width,
                height: card.height,
                wishlistHeartSize: wl.heartSize,
                wishlistChipExtent: wl.chipExtent,
                isWishlisted: wishlist.contains(product.id),
                onToggleWishlist: () {
                  ref.read(wishlistControllerProvider.notifier).toggle(product.id);
                },
                onTap: () => navigateToStorefrontProductDetails(
                  context,
                  ref,
                  product.id,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SuggestionSkeletonCard extends StatelessWidget {
  const _SuggestionSkeletonCard({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65);
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: width,
              color: base,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: width * 0.8,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: width * 0.48,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 12,
                      width: width * 0.52,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
