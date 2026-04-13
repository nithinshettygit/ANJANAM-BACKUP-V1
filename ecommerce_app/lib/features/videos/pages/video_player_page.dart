import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ecommerce_app/presentation/utils/universal_share.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';

import '../models/storefront_video.dart';
import '../utils/youtube_url_parser.dart';
import '../widgets/youtube_video_player_widget.dart';

/// Chrome-style mobile UA so YouTube treats the WebView closer to a normal browser tab.
String? _youtubeWebViewUserAgent() {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'Mozilla/5.0 (Linux; Android 13; Mobile) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/131.0.0.0 Mobile Safari/537.36';
    case TargetPlatform.iOS:
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Version/17.4 Mobile/15E148 Safari/604.1';
    default:
      return null;
  }
}

/// Storefront video playback: **mobile** uses the official `/embed/` URL in a WebView; **web**
/// keeps [youtube_player_iframe] (Flutter web). No stall timer or JS-bridge teardown that
/// falsely blocked working embeds.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.video});

  final StorefrontVideo video;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  int _embedSession = 0;
  bool _embedPageFinished = false;
  String? _embedLoadWarning;

  String? get _videoId => widget.video.videoId ?? extractYoutubeVideoId(widget.video.youtubeUrl);

  double get _playerAspectRatio =>
      widget.video.isYoutubeShortsLink ? 9 / 16 : 16 / 9;

  Future<void> _openOnYoutube() async {
    final id = _videoId;
    final uri = id != null
        ? (widget.video.isYoutubeShortsLink ? youtubeShortsPageUri(id) : youtubeWatchPageUri(id))
        : Uri.tryParse(widget.video.youtubeUrl.trim());
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _reloadEmbed() {
    setState(() {
      _embedSession++;
      _embedPageFinished = false;
      _embedLoadWarning = null;
    });
  }

  Future<void> _shareVideo(BuildContext context) async {
    final payload = UniversalSharePayload(
        contentType: ShareContentType.video,
        idOrSlug: widget.video.id,
        title: widget.video.title,
        description: widget.video.description,
        imageUrl: widget.video.effectiveThumbnailUrl,
      );
    try {
      await shareUniversalPayload(
        payload: payload,
        channel: ShareChannel.system,
      );
    } catch (_) {
      if (!context.mounted) return;
      await showUniversalShareSheet(context, payload: payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = widget.video.description?.trim();
    final id = _videoId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => _shareVideo(context),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.brandSaffron,
            ),
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: id == null
          ? _UnsupportedVideoView(
              theme: theme,
              title: widget.video.title,
              description: description,
              onWatchOnYoutube: _openOnYoutube,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  YouTubeVideoPlayerWidget(
                    key: ValueKey('player-$_embedSession-$id-${kIsWeb ? "web" : "mobile"}'),
                    videoId: id,
                    aspectRatio: _playerAspectRatio,
                    thumbnailUrl:
                        widget.video.effectiveThumbnailUrl ?? youtubeDefaultThumbnailUrl(id),
                    userAgent: _youtubeWebViewUserAgent(),
                    pageFinished: _embedPageFinished,
                    onPageFinished: () {
                      if (mounted) setState(() => _embedPageFinished = true);
                    },
                    onMainFrameError: (msg) {
                      if (mounted) setState(() => _embedLoadWarning = msg);
                    },
                    onWatchOnYoutube: _openOnYoutube,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      onPressed: _openOnYoutube,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Watch on YouTube'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: FilledButton.icon(
                      onPressed: () => _shareVideo(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandSaffron,
                        foregroundColor: Colors.white,
                        iconColor: Colors.white,
                      ),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share video'),
                    ),
                  ),
                  if (!kIsWeb)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: OutlinedButton.icon(
                        onPressed: _reloadEmbed,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reload player'),
                      ),
                    ),
                  if (_embedLoadWarning != null && _embedLoadWarning!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Card(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Load issue: $_embedLoadWarning\n'
                            'If the video allows embedding, try Reload player or Watch on YouTube.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!kIsWeb && !_embedPageFinished)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Card(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Opening YouTube’s player… Tap play in the video when it appears.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      widget.video.title,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (description != null && description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _UnsupportedVideoView extends StatelessWidget {
  const _UnsupportedVideoView({
    required this.theme,
    required this.title,
    required this.description,
    required this.onWatchOnYoutube,
  });

  final ThemeData theme;
  final String title;
  final String? description;
  final Future<void> Function() onWatchOnYoutube;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'This video link is not supported in-app.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: onWatchOnYoutube,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Watch on YouTube'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (description != null && description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
