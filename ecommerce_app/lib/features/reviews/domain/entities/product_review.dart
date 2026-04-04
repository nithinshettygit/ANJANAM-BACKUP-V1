class ProductReview {
  final String id;
  final String userId;
  final int rating;
  final String? reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerifiedPurchase;
  final String authorDisplayName;

  const ProductReview({
    required this.id,
    required this.userId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    required this.updatedAt,
    required this.isVerifiedPurchase,
    required this.authorDisplayName,
  });

  factory ProductReview.fromRpcRow(Map<String, dynamic> json) {
    DateTime parseTs(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (v is DateTime) return v.toUtc();
      return DateTime.tryParse(v.toString())?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return ProductReview(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      rating: (json['rating'] as num?)?.round() ?? 0,
      reviewText: json['review_text'] as String?,
      createdAt: parseTs(json['created_at']),
      updatedAt: parseTs(json['updated_at']),
      isVerifiedPurchase: json['is_verified_purchase'] == true,
      authorDisplayName: (json['author_display_name'] as String?)?.trim().isNotEmpty == true
          ? (json['author_display_name'] as String).trim()
          : 'Customer',
    );
  }
}
