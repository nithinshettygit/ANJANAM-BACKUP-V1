import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';

/// How storefront prices are interpreted:
///
/// - [Product.price] is always the **amount the customer pays** (sale price). Cart and
///   checkout use this value.
/// - [Product.displayDiscountPercent] is the marketing discount **off MRP** (1–99).
///   When set, **MRP** is derived so the math matches:
///   `salePrice = mrp × (1 − discount/100)` → `mrp = salePrice / (1 − discount/100)`.
class ProductPriceDisplay {
  ProductPriceDisplay._({
    required this.salePrice,
    required this.discountPercent,
    required this.mrp,
  });

  /// Payable amount (from database).
  final double salePrice;

  /// Admin-configured % off MRP (0 = no promo UI).
  final int discountPercent;

  /// Derived MRP / list price, or null when there is no promo.
  final double? mrp;

  /// Whether to show strikethrough MRP, badge, and discount copy.
  bool get showPromo =>
      mrp != null && discountPercent > 0 && salePrice > 0;

  /// `salePrice / (1 - discount/100)` for discount in 1..99.
  static double computeMrp(double salePrice, int discountPercent) {
    final d = discountPercent.clamp(1, 99);
    return salePrice / (1 - d / 100.0);
  }

  /// Discount % implied by [mrp] and [salePrice] (rounded); should match [discountPercent] barring FP noise.
  static int effectiveDiscountPercent(double mrp, double salePrice) {
    if (mrp <= 0 || salePrice <= 0 || salePrice >= mrp) return 0;
    return (((mrp - salePrice) / mrp) * 100).round().clamp(1, 99);
  }

  factory ProductPriceDisplay.forProduct(
    Product product, {
    bool hidePromoWhenOutOfStock = false,
    bool outOfStock = false,
  }) {
    final sale = product.price;
    final d = product.displayDiscountPercent.clamp(0, 99);
    final skip = d <= 0 ||
        sale <= 0 ||
        (hidePromoWhenOutOfStock && outOfStock);
    if (skip) {
      return ProductPriceDisplay._(
        salePrice: sale,
        discountPercent: 0,
        mrp: null,
      );
    }
    return ProductPriceDisplay._(
      salePrice: sale,
      discountPercent: d,
      mrp: computeMrp(sale, d),
    );
  }
}
