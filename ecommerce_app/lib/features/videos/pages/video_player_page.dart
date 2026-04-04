import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/storefront_video.dart';
import '../utils/youtube_url_parser.dart';

/// Full-screen friendly embedded YouTube player (iframe / WebView; works on web and mobile).
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.video});

  final StorefrontVideo video;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  bool _isPlayerReady = false;
  String? _playerErrorMessage;

  String? get _videoId => widget.video.videoId ?? extractYoutubeVideoId(widget.video.youtubeUrl);

  Future<void> _openOnYoutube() async {
    final uri = Uri.tryParse(widget.video.youtubeUrl.trim());
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    final id = _videoId;
    if (id == null) return;

    _controller = YoutubePlayerController.fromVideoId(
      videoId: id,
      params: const YoutubePlayerParams(
        showControls: true,
        mute: false,
        enableCaption: true,
        showFullscreenButton: true,
      ),
      autoPlay: false,
    );

    _sub = _controller!.stream.listen(_onPlayerValue);
  }

  void _onPlayerValue(YoutubePlayerValue value) {
    if (!mounted) return;
    if (value.hasError) {
      setState(() => _playerErrorMessage = 'YouTube player error: ${value.error}');
      return;
    }
    const readyStates = <PlayerState>{
      PlayerState.cued,
      PlayerState.playing,
      PlayerState.paused,
      PlayerState.buffering,
    };
    if (!_isPlayerReady && readyStates.contains(value.playerState)) {
      setState(() => _isPlayerReady = true);
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    unawaited(_controller?.close() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = widget.video.description?.trim();
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: controller == null
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
                  YoutubePlayer(
                    controller: controller,
                    aspectRatio: 16 / 9,
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
                  if (!_isPlayerReady || _playerErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Card(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _playerErrorMessage ??
                                'Loading player... If playback stays black, tap "Watch on YouTube".',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _playerErrorMessage != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
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
