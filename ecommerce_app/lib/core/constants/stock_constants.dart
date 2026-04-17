/// Minimum sellable units that count as "healthy" (not low) in admin inventory,
/// product filters, and the storefront banner.
///
/// Low stock: `sellable > 0 && sellable < kHealthyStockMin` (e.g. 1–9 when this is 10).
const int kHealthyStockMin = 10;

/// Matches admin [AdminInventoryRow.lowStock] and storefront low-stock messaging.
bool sellableStockIsLow(int? sellable) {
  if (sellable == null || sellable <= 0) return false;
  return sellable < kHealthyStockMin;
}
