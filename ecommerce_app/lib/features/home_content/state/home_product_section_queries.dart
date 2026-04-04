import '../../catalog/domain/product_sort_option.dart';
import '../../catalog/state/product_list_providers.dart';

/// Shared [ProductListQuery] keys for home rails (used with [productListProvider]).
const kHomePopularProductsQuery = ProductListQuery(
  popularOnly: true,
  limit: 16,
  offset: 0,
  sort: ProductSortOption.newest,
);

const kHomeRecommendedProductsQuery = ProductListQuery(
  recommendedOnly: true,
  limit: 16,
  offset: 0,
  sort: ProductSortOption.newest,
);

const kHomeFestivalProductsQuery = ProductListQuery(
  festivalSpecialOnly: true,
  limit: 16,
  offset: 0,
  sort: ProductSortOption.newest,
);

const kHomeNewArrivalsQuery = ProductListQuery(
  limit: 16,
  offset: 0,
  sort: ProductSortOption.newest,
);
