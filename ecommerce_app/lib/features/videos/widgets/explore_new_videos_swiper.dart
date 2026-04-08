import 'dart:async';

import 'package:ecommerce_app/features/videos/pages/video_player_page.dart';
import 'package:ecommerce_app/features/videos/providers/videos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExploreNewVideosSwiper extends ConsumerStatefulWidget {
  const ExploreNewVideosSwiper({super.key});

  @override
  ConsumerState<ExploreNewVideosSwiper> createState() =>
      _ExploreNewVideosSwiperState();
}

class _ExploreNewVideosSwiperState extends ConsumerState<ExploreNewVideosSwiper> {
  final PageController _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _index = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncAutoSwipe(int count) {
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homeVideosPreviewProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWideWeb = screenWidth >= 1100;
    final bool isTabletLike = screenWidth >= 700 && screenWidth < 1100;
    final double swiperHeight = isWideWeb
        ? 275
        : isTabletLike
            ? 258
            : 238;
    final double thumbHeight = isWideWeb
        ? 170
        : isTabletLike
            ? 158
            : 144;
    final double cardGapRight = isWideWeb ? 14 : 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fresh Watch',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/videos'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        async.when(
          loading: () => const SizedBox(
            height: 205,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (videos) {
            if (videos.isEmpty) {
              return const SizedBox.shrink();
            }
            _syncAutoSwipe(videos.length);
            return SizedBox(
              height: swiperHeight,
              child: PageView.builder(
                controller: _controller,
                itemCount: videos.length,
                onPageChanged: (v) => _index = v,
                itemBuilder: (context, i) {
                  final v = videos[i];
                  final thumb = v.effectiveThumbnailUrl;
                  return Padding(
                    padding: EdgeInsets.only(right: cardGapRight),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => VideoPlayerPage(video: v),
                          ),
                        );
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: thumbHeight,
                              width: double.infinity,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  thumb == null || thumb.isEmpty
                                      ? Container(
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: Icon(Icons.smart_display_outlined),
                                          ),
                                        )
                                      : Image.network(
                                          thumb,
                                          fit: BoxFit.cover,
                                        ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.55),
                                          Colors.black.withValues(alpha: 0.10),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Center(
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Color(0xCC000000),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                              child: Text(
                                v.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isWideWeb ? 16 : null,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.36),
                                      ),
                                    ),
                                    child: const Text(
                                      'VIDEO',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Tap to watch',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
