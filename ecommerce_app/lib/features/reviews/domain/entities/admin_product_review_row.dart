class AdminProductReviewRow {
  final String id;
  final String productId;
  final String productTitle;
  final String userId;
  final String reviewerName;
  final int rating;
  final String? reviewText;
  final bool isVerifiedPurchase;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminProductReviewRow({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.userId,
    required this.reviewerName,
    required this.rating,
    required this.reviewText,
    required this.isVerifiedPurchase,
    required this.isVisible,
    required this.createdAt,
    required this.updatedAt,
  });
}
