import 'dart:async';

import 'package:ecommerce_app/features/articles/pages/article_detail_page.dart';
import 'package:ecommerce_app/features/articles/providers/articles_providers.dart';
import 'package:ecommerce_app/features/explore_suggestions/providers/explore_suggestions_providers.dart';
import 'package:ecommerce_app/features/videos/pages/video_player_page.dart';
import 'package:ecommerce_app/features/videos/providers/videos_providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuggestedForYouCarousel extends ConsumerStatefulWidget {
  const SuggestedForYouCarousel({super.key});

  @override
  ConsumerState<SuggestedForYouCarousel> createState() => _SuggestedForYouCarouselState();
}

class _SuggestedForYouCarouselState extends ConsumerState<SuggestedForYouCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: kIsWeb ? 0.84 : 0.92,
  );
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
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(activeExploreSuggestionsProvider);
    final fallbackArticlesAsync = ref.watch(publishedArticlesProvider);
    final fallbackVideosAsync = ref.watch(homeVideosPreviewProvider);
    final theme = Theme.of(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final double loadingH;
    final double carouselH;
    final double titleFont;
    final double cardPadR;
    if (kIsWeb) {
      if (screenW >= 1200) {
        loadingH = 232;
        carouselH = 264;
        titleFont = 22;
        cardPadR = 12;
      } else if (screenW >= 800) {
        loadingH = 216;
        carouselH = 244;
        titleFont = 21;
        cardPadR = 11;
      } else {
        loadingH = 200;
        carouselH = 224;
        titleFont = 20;
        cardPadR = 10;
      }
    } else {
      loadingH = 180;
      carouselH = 190;
      titleFont = 20;
      cardPadR = 10;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested for you',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: kIsWeb && screenW >= 1100 ? 22 : null,
          ),
        ),
        const SizedBox(height: 8),
        suggestionsAsync.when(
          loading: () => SizedBox(
            height: loadingH,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            final cards = <_SuggestionCardModel>[];
            if (items.isNotEmpty) {
              cards.addAll(
                items.map(
                  (s) => _SuggestionCardModel(
                    contentType: s.contentType,
                    articleId: s.articleId,
                    videoId: s.videoId,
                    imageUrl: s.imageUrl,
                    badge: s.badgeLabel,
                    title: s.titleOverride,
                    subtitle: s.subtitleOverride,
                  ),
                ),
              );
            } else {
              final articleList = fallbackArticlesAsync.asData?.value ?? const [];
              final videoList = fallbackVideosAsync.asData?.value ?? const [];
              for (final a in articleList.take(4)) {
                cards.add(
                  _SuggestionCardModel(
                    contentType: 'article',
                    articleId: a.id,
                    imageUrl: a.coverImageUrl,
                    badge: 'Article',
                    title: a.title,
                    subtitle: a.authorName,
                  ),
                );
              }
              for (final v in videoList.take(4)) {
                cards.add(
                  _SuggestionCardModel(
                    contentType: 'video',
                    videoId: v.id,
                    imageUrl: v.effectiveThumbnailUrl,
                    badge: 'Video',
                    title: v.title,
                    subtitle: v.description,
                  ),
                );
              }
            }

            if (cards.isEmpty) return const SizedBox.shrink();
            _syncAutoSwipe(cards.length);
            return SizedBox(
              height: carouselH,
              child: PageView.builder(
                controller: _controller,
                itemCount: cards.length,
                onPageChanged: (v) => _index = v,
                itemBuilder: (context, i) {
                  final s = cards[i];
                  final isArticle = s.contentType == 'article';
                  return Padding(
                    padding: EdgeInsets.only(right: cardPadR),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openTarget(context, s.contentType, s.articleId, s.videoId),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: s.imageUrl != null && s.imageUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(s.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.65),
                                Colors.black.withValues(alpha: 0.12),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isArticle
                                      ? Colors.deepPurple.withValues(alpha: 0.92)
                                      : Colors.red.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  (s.badge?.trim().isNotEmpty == true
                                          ? s.badge!
                                          : (isArticle ? 'ARTICLE' : 'VIDEO'))
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                s.title?.trim().isNotEmpty == true
                                    ? s.title!
                                    : (isArticle ? 'Featured article' : 'Featured video'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: titleFont,
                                ),
                              ),
                              if (s.subtitle?.trim().isNotEmpty == true)
                                Text(
                                  s.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                            ],
                          ),
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

  Future<void> _openTarget(
    BuildContext context,
    String contentType,
    String? articleId,
    String? videoId,
  ) async {
    if (contentType == 'article' && articleId != null && articleId.isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ArticleDetailPage(articleId: articleId),
        ),
      );
      return;
    }
    if (contentType == 'video' && videoId != null && videoId.isNotEmpty) {
      final video = await ref.read(videoByIdProvider(videoId).future);
      if (video == null || !context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerPage(video: video),
        ),
      );
    }
  }
}

class _SuggestionCardModel {
  final String contentType;
  final String? articleId;
  final String? videoId;
  final String? imageUrl;
  final String? badge;
  final String? title;
  final String? subtitle;

  _SuggestionCardModel({
    required this.contentType,
    this.articleId,
    this.videoId,
    this.imageUrl,
    this.badge,
    this.title,
    this.subtitle,
  });
}
