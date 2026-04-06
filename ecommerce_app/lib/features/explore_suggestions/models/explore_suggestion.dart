class ExploreSuggestion {
  final String id;
  final String contentType;
  final String? articleId;
  final String? videoId;
  final String? titleOverride;
  final String? subtitleOverride;
  final String? imageUrl;
  final String? badgeLabel;
  final bool isActive;
  final int sortOrder;

  const ExploreSuggestion({
    required this.id,
    required this.contentType,
    required this.articleId,
    required this.videoId,
    required this.titleOverride,
    required this.subtitleOverride,
    required this.imageUrl,
    required this.badgeLabel,
    required this.isActive,
    required this.sortOrder,
  });

  factory ExploreSuggestion.fromRow(Map<String, dynamic> row) {
    return ExploreSuggestion(
      id: (row['id'] ?? '').toString(),
      contentType: (row['content_type'] ?? '').toString(),
      articleId: row['article_id']?.toString(),
      videoId: row['video_id']?.toString(),
      titleOverride: row['title_override']?.toString(),
      subtitleOverride: row['subtitle_override']?.toString(),
      imageUrl: row['image_url']?.toString(),
      badgeLabel: row['badge_label']?.toString(),
      isActive: row['is_active'] == true,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
