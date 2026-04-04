import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';

import '../models/storefront_video.dart';
import '../utils/youtube_url_parser.dart';

String? _nullableTrim(String? value) {
  if (value == null) return null;
  final t = value.trim();
  return t.isEmpty ? null : t;
}

class VideosSupabaseService extends SupabaseServiceBase {
  VideosSupabaseService(super.client);

  static const _columns =
      'id, title, description, youtube_url, thumbnail_url, category, is_active, created_at';

  Future<({List<StorefrontVideo> items, bool hasMore})> fetchActiveVideos({
    required int offset,
    int limit = 20,
  }) async {
    final take = limit + 1;
    final end = offset + take - 1;
    final data = await guard(
      () => client
          .from('videos')
          .select(_columns)
          .order('created_at', ascending: false)
          .range(offset, end),
    );
    final list = (data as List).cast<Map<String, dynamic>>();

    // Keep the client-side filter as a safety net in case the API-side boolean
    // filter behaves unexpectedly across PostgREST/Supabase versions.
    final active = list.where((row) => row['is_active'] == true).toList();
    final hasMore = active.length > limit;
    final slice = hasMore ? active.sublist(0, limit) : active;
    return (
      items: slice.map(StorefrontVideo.fromRow).toList(),
      hasMore: hasMore,
    );
  }

  Future<List<StorefrontVideo>> fetchAdminVideos({int limit = 500}) async {
    final data = await guard(
      () => client
          .from('videos')
          .select(_columns)
          .order('created_at', ascending: false)
          .range(0, limit - 1),
    );
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(StorefrontVideo.fromRow)
        .toList();
  }

  Future<void> insertVideo({
    required String title,
    required String youtubeUrl,
    String? description,
    String? category,
    bool isActive = true,
    String? thumbnailUrl,
  }) async {
    final id = extractYoutubeVideoId(youtubeUrl);
    if (id == null) {
      throw ArgumentError('Invalid YouTube URL');
    }
    final thumb = (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty)
        ? thumbnailUrl.trim()
        : youtubeDefaultThumbnailUrl(id);
    await guard(
      () => client.from('videos').insert({
        'title': title.trim(),
        'description': _nullableTrim(description),
        'youtube_url': youtubeUrl.trim(),
        'thumbnail_url': thumb,
        'category': _nullableTrim(category),
        'is_active': isActive,
      }),
    );
  }

  Future<void> updateVideo({
    required String id,
    required String title,
    required String youtubeUrl,
    String? description,
    String? category,
    required bool isActive,
    String? thumbnailUrl,
  }) async {
    final vid = extractYoutubeVideoId(youtubeUrl);
    if (vid == null) {
      throw ArgumentError('Invalid YouTube URL');
    }
    final thumb = (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty)
        ? thumbnailUrl.trim()
        : youtubeDefaultThumbnailUrl(vid);
    await guard(
      () => client.from('videos').update({
        'title': title.trim(),
        'description': _nullableTrim(description),
        'youtube_url': youtubeUrl.trim(),
        'thumbnail_url': thumb,
        'category': _nullableTrim(category),
        'is_active': isActive,
      }).eq('id', id),
    );
  }

  Future<void> deleteVideo(String id) async {
    await guard(() => client.from('videos').delete().eq('id', id));
  }
}
