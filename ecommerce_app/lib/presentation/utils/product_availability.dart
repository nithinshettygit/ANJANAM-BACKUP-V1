import 'package:ecommerce_app/core/constants/stock_constants.dart';
import 'package:ecommerce_app/features/catalog/domain/entities/product.dart';
import 'package:ecommerce_app/l10n/app_localizations.dart';

/// [inventoryCount] null = not tracked in UI; treat as available.
bool productIsOutOfStock(Product product) {
  final n = product.sellableStock;
  if (n == null) return false;
  return n <= 0;
}

bool productIsLowStock(Product product) {
  return sellableStockIsLow(product.sellableStock);
}

/// Short label for chips / detail row (null = no extra banner).
String? productStockBannerText(Product product, AppLocalizations localizations) {
  if (productIsOutOfStock(product)) return localizations.outOfStock;
  if (productIsLowStock(product)) return localizations.onlyFewLeft;
  return null;
}

/// Upper bound for quantity selectors. Null inventory = cap at [whenUnlimited].
int maxSelectableQuantity(Product product, {int whenUnlimited = 99}) {
  final inv = product.sellableStock;
  if (inv == null) return whenUnlimited;
  if (inv < 1) return 1;
  return inv > whenUnlimited ? whenUnlimited : inv;
}
