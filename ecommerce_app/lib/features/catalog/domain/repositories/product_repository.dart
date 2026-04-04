import '../entities/product.dart';
import '../product_sort_option.dart';

abstract class ProductRepository {
  Future<List<Product>> fetchProducts({
    String? category,
    /// Storefront search: whitespace splits into AND tokens; each token matches if it
    /// appears in title, category, description, or (exact) product tags.
    String? nameSearch,
    double? minPrice,
    double? maxPrice,
    bool inStockOnly = false,
    bool popularOnly = false,
    bool recommendedOnly = false,
    bool festivalSpecialOnly = false,
    ProductSortOption sort = ProductSortOption.newest,
    int limit = 20,
    int offset = 0,
  });

  Future<Product> fetchProductById(String productId);

  Future<List<Product>> fetchSimilarProducts({
    required String currentProductId,
    String? category,
    String? title,
    List<String> tags = const [],
    int limit = 8,
  });

  /// Active products matching [ids] (preserves first-seen id order; chunks large lists).
  Future<List<Product>> fetchProductsByIds(List<String> ids);
}

