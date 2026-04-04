class ProductAnswer {
  final String id;
  final String userId;
  final String answer;
  final bool isAdmin;
  /// True when posted by a customer with a delivered order for this product.
  final bool isVerifiedPurchase;
  final DateTime createdAt;
  final String authorDisplayName;

  const ProductAnswer({
    required this.id,
    required this.userId,
    required this.answer,
    required this.isAdmin,
    required this.isVerifiedPurchase,
    required this.createdAt,
    required this.authorDisplayName,
  });

  /// Storefront badge under the answer body.
  String? get answerBadgeLabel {
    if (isAdmin) return 'Seller Answer';
    if (isVerifiedPurchase) return 'Verified Buyer';
    return null;
  }

  static DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  factory ProductAnswer.fromJson(Map<String, dynamic> json) {
    return ProductAnswer(
      id: json['id'].toString(),
      userId: (json['user_id'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      isAdmin: json['is_admin'] == true,
      isVerifiedPurchase: json['is_verified_purchase'] == true,
      createdAt: _parseTs(json['created_at']),
      authorDisplayName: (json['author_display_name'] as String?)?.trim().isNotEmpty == true
          ? (json['author_display_name'] as String).trim()
          : 'Customer',
    );
  }
}
