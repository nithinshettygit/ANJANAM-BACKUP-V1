import 'package:flutter/material.dart';

/// Very light press feedback (scale ~0.98) without blocking child gestures.
class SubtleScaleOnPointer extends StatefulWidget {
  const SubtleScaleOnPointer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<SubtleScaleOnPointer> createState() => _SubtleScaleOnPointerState();
}

class _SubtleScaleOnPointerState extends State<SubtleScaleOnPointer> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
