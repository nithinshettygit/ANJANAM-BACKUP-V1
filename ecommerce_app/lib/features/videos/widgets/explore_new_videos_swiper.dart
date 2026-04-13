import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/features/videos/pages/video_player_page.dart';
import 'package:ecommerce_app/features/videos/providers/videos_providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExploreNewVideosSwiper extends ConsumerStatefulWidget {
  const ExploreNewVideosSwiper({super.key});

  @override
  ConsumerState<ExploreNewVideosSwiper> createState() =>
      _ExploreNewVideosSwiperState();
}

class _ExploreNewVideosSwiperState extends ConsumerState<ExploreNewVideosSwiper> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homeVideosPreviewProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isWideWeb = kIsWeb && screenWidth >= 1100;
    final bool isTabletLike = screenWidth >= 700 && screenWidth < 1100;
    final double cardGapRight = isWideWeb ? 16 : 12;
    final double cardWidth = isWideWeb
        ? 320
        : isTabletLike
            ? 320
            : (screenWidth * (kIsWeb ? 0.62 : 0.82)).clamp(260.0, 300.0);
    final double thumbHeight = cardWidth * 9 / 16;
    final double swiperHeight = thumbHeight + 66;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fresh Watch',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: isWideWeb ? 18.5 : null,
              ),
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
          loading: () => SizedBox(
            height: swiperHeight,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (videos) {
            if (videos.isEmpty) {
              return const SizedBox.shrink();
            }
            return SizedBox(
              height: swiperHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: videos.length,
                separatorBuilder: (_, __) => SizedBox(width: cardGapRight),
                itemBuilder: (context, i) {
                  final v = videos[i];
                  final thumb = v.effectiveThumbnailUrl;
                  return SizedBox(
                    width: cardWidth,
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
                        elevation: 1.4,
                        shadowColor: Colors.black.withValues(alpha: 0.16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
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
                                          Colors.black.withValues(alpha: 0.42),
                                          Colors.black.withValues(alpha: 0.18),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Center(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xB3000000),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 3),
                              child: Text(
                                v.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isWideWeb ? 16 : null,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandSaffron.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.brandSaffron.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'VIDEO',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: AppColors.brandSaffronDeep,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          size: 14,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Watch',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
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
