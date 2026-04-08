import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';

/// Above this count, stock is not shown as "low" on cards.
const int kLowStockMaxExclusive = 10;

/// [inventoryCount] null = not tracked in UI; treat as available.
bool productIsOutOfStock(Product product) {
  final n = product.sellableStock;
  if (n == null) return false;
  return n <= 0;
}

bool productIsLowStock(Product product) {
  final n = product.sellableStock;
  if (n == null || n <= 0) return false;
  return n <= kLowStockMaxExclusive;
}

/// Short label for chips / detail row (null = no extra banner).
String? productStockBannerText(Product product) {
  if (productIsOutOfStock(product)) return 'Out of stock';
  if (productIsLowStock(product)) {
    final n = product.sellableStock!;
    return n == 1 ? 'Only 1 left' : 'Only $n left';
  }
  return null;
}

/// Upper bound for quantity selectors. Null inventory = cap at [whenUnlimited].
int maxSelectableQuantity(Product product, {int whenUnlimited = 99}) {
  final inv = product.sellableStock;
  if (inv == null) return whenUnlimited;
  if (inv < 1) return 1;
  return inv > whenUnlimited ? whenUnlimited : inv;
}
