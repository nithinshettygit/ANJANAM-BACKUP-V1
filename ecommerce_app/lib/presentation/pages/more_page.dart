import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('More')),
      body: const PageEmptyState(
        icon: Icons.hourglass_top_rounded,
        title: 'More section coming soon',
        subtitle: 'Videos and music features will be added here.',
      ),
    );
  }
}

