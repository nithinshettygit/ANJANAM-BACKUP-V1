import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/storefront_video.dart';
import '../widgets/videos_list.dart';
import 'video_player_page.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final ScrollController _videosScrollController = ScrollController();

  @override
  void dispose() {
    _videosScrollController.dispose();
    super.dispose();
  }

  Future<void> _goToTop() async {
    if (!_videosScrollController.hasClients) return;
    await _videosScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Videos'),
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _goToTop,
            icon: const Icon(Icons.vertical_align_top_rounded),
            label: const Text('Top'),
          ),
        ],
      ),
      body: VideosList(
        scrollController: _videosScrollController,
        onVideoSelected: (StorefrontVideo video) {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => VideoPlayerPage(video: video),
            ),
          );
        },
      ),
    );
  }
}
