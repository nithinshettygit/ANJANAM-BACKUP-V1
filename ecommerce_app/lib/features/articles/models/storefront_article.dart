class StorefrontArticle {
  final String id;
  final String title;
  final String description;
  final String authorName;
  final String authorBio;
  final String? authorPhotoUrl;
  final String? coverImageUrl;
  final String pdfPath;
  final String? category;
  final bool isFree;
  final double price;
  final bool isPublished;
  final bool isFeatured;
  final bool isTrending;
  final String? checkoutProductId;
  final DateTime createdAt;

  const StorefrontArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.authorName,
    required this.authorBio,
    required this.authorPhotoUrl,
    required this.coverImageUrl,
    required this.pdfPath,
    required this.category,
    required this.isFree,
    required this.price,
    required this.isPublished,
    required this.isFeatured,
    required this.isTrending,
    required this.checkoutProductId,
    required this.createdAt,
  });

  factory StorefrontArticle.fromRow(Map<String, dynamic> row) {
    final created = row['created_at'];
    final createdAt = created is DateTime
        ? created
        : DateTime.tryParse(created?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    return StorefrontArticle(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      authorName: (row['author_name'] ?? '').toString(),
      authorBio: (row['author_bio'] ?? '').toString(),
      authorPhotoUrl: row['author_photo_url']?.toString(),
      coverImageUrl: row['cover_image_url']?.toString(),
      pdfPath: (row['pdf_url'] ?? '').toString(),
      category: row['category']?.toString(),
      isFree: row['is_free'] == true,
      price: (row['price'] as num?)?.toDouble() ?? 0,
      isPublished: row['is_published'] == true,
      isFeatured: row['is_featured'] == true,
      isTrending: row['is_trending'] == true,
      checkoutProductId: row['checkout_product_id']?.toString(),
      createdAt: createdAt,
    );
  }
}
