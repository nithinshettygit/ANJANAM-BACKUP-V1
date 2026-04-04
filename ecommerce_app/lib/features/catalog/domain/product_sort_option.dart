/// Storefront catalog ordering (applied server-side with stable secondary key).
enum ProductSortOption {
  newest,
  priceLowToHigh,
  priceHighToLow,
}

extension ProductSortOptionStorefront on ProductSortOption {
  String get storefrontLabel => switch (this) {
        ProductSortOption.newest => 'Newest first',
        ProductSortOption.priceLowToHigh => 'Price: low to high',
        ProductSortOption.priceHighToLow => 'Price: high to low',
      };
}
