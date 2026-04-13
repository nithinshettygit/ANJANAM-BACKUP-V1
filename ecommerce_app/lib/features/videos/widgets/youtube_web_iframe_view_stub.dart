import 'package:flutter/material.dart';

class YoutubeWebIFrameView extends StatelessWidget {
  const YoutubeWebIFrameView({
    super.key,
    required this.videoId,
    this.onReady,
    this.onError,
  });

  final String videoId;
  final VoidCallback? onReady;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
