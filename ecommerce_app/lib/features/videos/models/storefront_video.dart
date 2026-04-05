import '../utils/youtube_url_parser.dart';

class StorefrontVideo {
  final String id;
  final String title;
  final String? description;
  final String youtubeUrl;
  final String? thumbnailUrl;
  final String? category;
  final bool isActive;
  final DateTime createdAt;

  const StorefrontVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.youtubeUrl,
    required this.thumbnailUrl,
    required this.category,
    required this.isActive,
    required this.createdAt,
  });

  String? get videoId => extractYoutubeVideoId(youtubeUrl);

  /// Vertical Shorts links (`/shorts/<id>`) need a 9:16 player area; regular videos use 16:9.
  bool get isYoutubeShortsLink => isYoutubeShortsUrl(youtubeUrl);

  String? get effectiveThumbnailUrl {
    final custom = thumbnailUrl?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final vid = videoId;
    if (vid == null) return null;
    return youtubeDefaultThumbnailUrl(vid);
  }

  factory StorefrontVideo.fromRow(Map<String, dynamic> row) {
    final created = row['created_at'];
    DateTime createdAt;
    if (created is DateTime) {
      createdAt = created;
    } else {
      createdAt = DateTime.tryParse(created?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return StorefrontVideo(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      description: row['description']?.toString(),
      youtubeUrl: (row['youtube_url'] ?? '').toString(),
      thumbnailUrl: row['thumbnail_url']?.toString(),
      category: row['category']?.toString(),
      isActive: row['is_active'] == true,
      createdAt: createdAt,
    );
  }

}
