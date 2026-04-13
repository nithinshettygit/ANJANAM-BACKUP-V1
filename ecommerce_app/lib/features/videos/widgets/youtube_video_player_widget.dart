import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'youtube_embed_webview.dart';
import 'youtube_web_iframe_view_stub.dart'
    if (dart.library.html) 'youtube_web_iframe_view_web.dart';

class YouTubeVideoPlayerWidget extends StatelessWidget {
  const YouTubeVideoPlayerWidget({
    super.key,
    required this.videoId,
    required this.aspectRatio,
    required this.thumbnailUrl,
    required this.onWatchOnYoutube,
    this.userAgent,
    this.pageFinished = false,
    this.onPageFinished,
    this.onMainFrameError,
  });

  final String videoId;
  final double aspectRatio;
  final String thumbnailUrl;
  final String? userAgent;
  final bool pageFinished;
  final VoidCallback? onPageFinished;
  final void Function(String description)? onMainFrameError;
  final Future<void> Function() onWatchOnYoutube;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _WebYouTubePlayer(
        key: ValueKey('web-player-$videoId'),
        videoId: videoId,
        aspectRatio: aspectRatio,
        thumbnailUrl: thumbnailUrl,
        onWatchOnYoutube: onWatchOnYoutube,
      );
    }
    return _MobileYoutubeEmbed(
      videoId: videoId,
      aspectRatio: aspectRatio,
      thumbnailUrl: thumbnailUrl,
      userAgent: userAgent,
      onPageFinished: onPageFinished ?? () {},
      onMainFrameError: onMainFrameError ?? (_) {},
      pageFinished: pageFinished,
    );
  }
}

class _MobileYoutubeEmbed extends StatelessWidget {
  const _MobileYoutubeEmbed({
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

class _WebYouTubePlayer extends StatefulWidget {
  const _WebYouTubePlayer({
    super.key,
    required this.videoId,
    required this.aspectRatio,
    required this.thumbnailUrl,
    required this.onWatchOnYoutube,
  });

  final String videoId;
  final double aspectRatio;
  final String thumbnailUrl;
  final Future<void> Function() onWatchOnYoutube;

  @override
  State<_WebYouTubePlayer> createState() => _WebYouTubePlayerState();
}

class _WebYouTubePlayerState extends State<_WebYouTubePlayer> {
  bool _frameLoaded = false;
  bool _frameError = false;
  Timer? _failSafeTimer;

  @override
  void initState() {
    super.initState();
    _armFailSafe();
  }

  @override
  void dispose() {
    _failSafeTimer?.cancel();
    super.dispose();
  }

  void _armFailSafe() {
    _failSafeTimer?.cancel();
    _failSafeTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _frameLoaded) return;
      setState(() => _frameError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isShorts = widget.aspectRatio < 1;
    final maxPlayerWidth = isShorts
        ? (screenWidth >= 1200 ? 420.0 : 380.0)
        : (screenWidth >= 1500
            ? 1200.0
            : screenWidth >= 1200
                ? 1080.0
                : double.infinity);

    if (_frameError) {
      return _WebPlayerFrame(
        isShorts: isShorts,
        maxWidth: maxPlayerWidth,
        child: _WebYoutubeFallback(
          aspectRatio: widget.aspectRatio,
          thumbnailUrl: widget.thumbnailUrl,
          onWatchOnYoutube: widget.onWatchOnYoutube,
        ),
      );
    }

    return _WebPlayerFrame(
      isShorts: isShorts,
      maxWidth: maxPlayerWidth,
      child: ClipRect(
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              YoutubeWebIFrameView(
                key: ValueKey('yt-iframe-${widget.videoId}'),
                videoId: widget.videoId,
                onReady: () {
                  if (!mounted) return;
                  _failSafeTimer?.cancel();
                  setState(() {
                    _frameLoaded = true;
                    _frameError = false;
                  });
                },
                onError: () {
                  if (!mounted) return;
                  _failSafeTimer?.cancel();
                  setState(() => _frameError = true);
                },
              ),
              if (!_frameLoaded)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: const Center(child: CircularProgressIndicator.adaptive()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebPlayerFrame extends StatelessWidget {
  const _WebPlayerFrame({
    required this.maxWidth,
    required this.child,
    required this.isShorts,
  });

  final double maxWidth;
  final Widget child;
  final bool isShorts;

  @override
  Widget build(BuildContext context) {
    final wrappedChild = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
    if (!isShorts) return wrappedChild;

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.16),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.16),
            ],
          ),
        ),
        child: wrappedChild,
      ),
    );
  }
}

class _WebYoutubeFallback extends StatelessWidget {
  const _WebYoutubeFallback({
    required this.aspectRatio,
    required this.thumbnailUrl,
    required this.onWatchOnYoutube,
  });

  final double aspectRatio;
  final String thumbnailUrl;
  final Future<void> Function() onWatchOnYoutube;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
          Center(
            child: FilledButton.icon(
              onPressed: onWatchOnYoutube,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Watch on YouTube'),
            ),
          ),
        ],
      ),
    );
  }
}
