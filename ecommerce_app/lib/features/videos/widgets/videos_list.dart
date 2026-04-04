import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/storefront_video.dart';
import '../providers/videos_providers.dart';
import 'video_card.dart';

/// Scrollable grid of videos; does not embed players — opens [onVideoSelected] per tap.
class VideosList extends ConsumerStatefulWidget {
  const VideosList({
    super.key,
    required this.onVideoSelected,
    this.scrollController,
  });

  final void Function(StorefrontVideo video) onVideoSelected;
  final ScrollController? scrollController;

  @override
  ConsumerState<VideosList> createState() => _VideosListState();
}

class _VideosListState extends ConsumerState<VideosList> {
  late final ScrollController _scrollController;
  late final bool _ownsController;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final showScrollToTop = _scrollController.offset > 360;
    if (showScrollToTop != _showScrollToTop) {
      setState(() => _showScrollToTop = showScrollToTop);
    }
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max <= 0) return;
    if (current >= max * 0.85) {
      ref.read(videosFeedProvider.notifier).loadMore();
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(videosFeedProvider);
    final notifier = ref.read(videosFeedProvider.notifier);

    if (feed.initialLoading && feed.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feed.error != null && feed.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load videos.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              Text(
                feed.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => notifier.refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (feed.items.isEmpty) {
      return Center(
        child: Text(
          'No videos yet.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    final listView = RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 900
              ? 3
              : width >= 600
                  ? 2
                  : 1;
          if (crossAxisCount == 1) {
            return ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: feed.items.length + (feed.loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index >= feed.items.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final video = feed.items[index];
                return VideoCard(
                  video: video,
                  onTap: () => widget.onVideoSelected(video),
                );
              },
            );
          }
          return GridView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.94,
            ),
            itemCount: feed.items.length + (feed.loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= feed.items.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final video = feed.items[index];
              return VideoCard(
                video: video,
                onTap: () => widget.onVideoSelected(video),
              );
            },
          );
        },
      ),
    );

    return Stack(
      children: [
        listView,
        Positioned(
          right: 16,
          bottom: 16,
          child: IgnorePointer(
            ignoring: !_showScrollToTop,
            child: AnimatedOpacity(
              opacity: _showScrollToTop ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: FloatingActionButton.small(
                heroTag: 'videosScrollToTop',
                tooltip: 'Go to top',
                onPressed: _scrollToTop,
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
