import 'package:flutter/material.dart';

import '../../features/videos/pages/videos_screen.dart';

/// Route wrapper for `/videos` so Explore -> Videos always opens the new module.
class VideosPage extends StatelessWidget {
  const VideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideosScreen();
  }
}
