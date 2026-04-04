import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/material.dart';

class MusicPage extends StatelessWidget {
  const MusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music')),
      body: PageEmptyState(
        icon: Icons.music_note_outlined,
        title: 'Music coming soon',
        subtitle: 'This section will include music content in a future update.',
      ),
    );
  }
}

