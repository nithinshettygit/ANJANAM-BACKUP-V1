import '../../../catalog/domain/entities/product.dart';

/// UI-facing details object for the product details screen.
class ProductDetail {
  final Product product;

  const ProductDetail({
    required this.product,
  });

  factory ProductDetail.fromProduct(Product product) {
    // Extend this factory once you add richer `product_details` table data.
    return ProductDetail(product: product);
  }
}

