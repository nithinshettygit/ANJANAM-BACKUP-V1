import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';

import '../models/storefront_video.dart';
import '../services/videos_supabase_service.dart';

final videosSupabaseServiceProvider = Provider<VideosSupabaseService>(
  (ref) => VideosSupabaseService(ref.watch(supabaseClientProvider)),
);

/// Bumps when storefront video data should refetch (e.g. after admin changes from another device).
final videosStorefrontRevisionProvider =
    NotifierProvider<VideosStorefrontRevisionNotifier, int>(
  VideosStorefrontRevisionNotifier.new,
);

class VideosStorefrontRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final homeVideosPreviewProvider = FutureProvider.autoDispose<List<StorefrontVideo>>((ref) async {
  ref.watch(videosStorefrontRevisionProvider);
  final svc = ref.watch(videosSupabaseServiceProvider);
  final page = await svc.fetchActiveVideos(offset: 0, limit: 8);
  return page.items;
});

final adminVideosListProvider = FutureProvider.autoDispose<List<StorefrontVideo>>((ref) async {
  final svc = ref.watch(videosSupabaseServiceProvider);
  return svc.fetchAdminVideos(limit: 500);
});

final videoByIdProvider =
    FutureProvider.autoDispose.family<StorefrontVideo?, String>((ref, id) async {
  final svc = ref.watch(videosSupabaseServiceProvider);
  return svc.fetchVideoById(id);
});

class VideosFeedState {
  final List<StorefrontVideo> items;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  const VideosFeedState({
    this.items = const [],
    this.initialLoading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  VideosFeedState copyWith({
    List<StorefrontVideo>? items,
    bool? initialLoading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return VideosFeedState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final videosFeedProvider =
    NotifierProvider<VideosFeedNotifier, VideosFeedState>(VideosFeedNotifier.new);

class VideosFeedNotifier extends Notifier<VideosFeedState> {
  static const _pageSize = 20;

  @override
  VideosFeedState build() {
    ref.listen<int>(videosStorefrontRevisionProvider, (_, __) {
      unawaited(refresh());
    });
    unawaited(_fetchFirstPage());
    return const VideosFeedState(initialLoading: true);
  }

  VideosSupabaseService get _service => ref.read(videosSupabaseServiceProvider);

  Future<void> _fetchFirstPage() async {
    try {
      final page = await _service.fetchActiveVideos(offset: 0, limit: _pageSize);
      state = VideosFeedState(
        items: page.items,
        initialLoading: false,
        loadingMore: false,
        hasMore: page.hasMore,
        error: null,
      );
    } catch (e) {
      state = VideosFeedState(
        items: const [],
        initialLoading: false,
        loadingMore: false,
        hasMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(initialLoading: true, clearError: true, items: const []);
    await _fetchFirstPage();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.initialLoading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _service.fetchActiveVideos(
        offset: state.items.length,
        limit: _pageSize,
      );
      state = VideosFeedState(
        items: [...state.items, ...page.items],
        initialLoading: false,
        loadingMore: false,
        hasMore: page.hasMore,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }
}
