import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:ecommerce_app/presentation/utils/universal_share.dart';

import '../models/storefront_video.dart';
import '../utils/youtube_url_parser.dart';
import '../widgets/youtube_embed_webview.dart';

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
    await showUniversalShareSheet(
      context,
      payload: UniversalSharePayload(
        contentType: ShareContentType.video,
        idOrSlug: widget.video.id,
        title: widget.video.title,
        description: widget.video.description,
        imageUrl: widget.video.effectiveThumbnailUrl,
      ),
    );
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
            icon: const Icon(Icons.share_outlined),
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
                  if (kIsWeb)
                    _WebYoutubePlayer(videoId: id, aspectRatio: _playerAspectRatio)
                  else
                    _MobileYoutubeEmbed(
                      key: ValueKey('mobile-$_embedSession-$id'),
                      videoId: id,
                      aspectRatio: _playerAspectRatio,
                      thumbnailUrl:
                          widget.video.effectiveThumbnailUrl ?? youtubeDefaultThumbnailUrl(id),
                      userAgent: _youtubeWebViewUserAgent(),
                      onPageFinished: () {
                        if (mounted) setState(() => _embedPageFinished = true);
                      },
                      onMainFrameError: (msg) {
                        if (mounted) setState(() => _embedLoadWarning = msg);
                      },
                      pageFinished: _embedPageFinished,
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

class _MobileYoutubeEmbed extends StatelessWidget {
  const _MobileYoutubeEmbed({
    super.key,
    required this.videoId,
    required this.aspectRatio,
    required this.thumbnailUrl,
    required this.userAgent,
    required this.onPageFinished,
    required this.onMainFrameError,
    required this.pageFinished,
  });

  final String videoId;
  final double aspectRatio;
  final String thumbnailUrl;
  final String? userAgent;
  final VoidCallback onPageFinished;
  final void Function(String description) onMainFrameError;
  final bool pageFinished;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ClipRect(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => ColoredBox(color: surface),
              ),
            ),
            YoutubeEmbedWebView(
              videoId: videoId,
              userAgent: userAgent,
              onEmbedReady: onPageFinished,
              onMainFrameError: onMainFrameError,
            ),
            if (!pageFinished)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator.adaptive(),
                      SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Loading YouTube…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WebYoutubePlayer extends StatefulWidget {
  const _WebYoutubePlayer({required this.videoId, required this.aspectRatio});

  final String videoId;
  final double aspectRatio;

  @override
  State<_WebYoutubePlayer> createState() => _WebYoutubePlayerState();
}

class _WebYoutubePlayerState extends State<_WebYoutubePlayer> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      params: const YoutubePlayerParams(
        showControls: true,
        mute: false,
        enableCaption: true,
        showFullscreenButton: true,
      ),
      autoPlay: false,
    );
  }

  @override
  void dispose() {
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: YoutubePlayer(
          controller: _controller,
          aspectRatio: widget.aspectRatio,
          backgroundColor: Colors.transparent,
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
