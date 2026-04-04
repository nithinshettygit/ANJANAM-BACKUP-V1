import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Horizontal product rail with optional **web** mouse-wheel → horizontal scroll and scrollbar.
///
/// On **Android / iOS**, builds a plain [ListView.separated] with no controller.
class WebHorizontalRailList extends StatefulWidget {
  const WebHorizontalRailList({
    super.key,
    required this.height,
    this.padding,
    required this.itemCount,
    required this.itemBuilder,
    required this.separatorBuilder,
    this.physics,
    /// Extra bottom inset inside the list so the horizontal scrollbar clears card artwork (web).
    this.scrollbarBottomInset,
  });

  final double height;
  final EdgeInsetsGeometry? padding;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder separatorBuilder;
  final ScrollPhysics? physics;
  final double? scrollbarBottomInset;

  @override
  State<WebHorizontalRailList> createState() => _WebHorizontalRailListState();
}

class _WebHorizontalRailListState extends State<WebHorizontalRailList> {
  ScrollController? _controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _controller = ScrollController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!kIsWeb || event is! PointerScrollEvent) return;
    final c = _controller;
    if (c == null || !c.hasClients) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;
    final next = (c.offset + delta).clamp(0.0, c.position.maxScrollExtent);
    c.jumpTo(next);
  }

  EdgeInsets _resolvedListPadding(BuildContext context) {
    final base = widget.padding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;
    final extraBottom = kIsWeb ? (widget.scrollbarBottomInset ?? 14) : 0.0;
    return base.copyWith(bottom: base.bottom + extraBottom);
  }

  @override
  Widget build(BuildContext context) {
    final list = SizedBox(
      height: widget.height,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: _resolvedListPadding(context),
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        separatorBuilder: widget.separatorBuilder,
        itemBuilder: widget.itemBuilder,
      ),
    );

    if (!kIsWeb) return list;

    final scheme = Theme.of(context).colorScheme;
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thickness: WidgetStateProperty.all(9),
            radius: const Radius.circular(8),
            thumbVisibility: WidgetStateProperty.all(true),
            trackVisibility: WidgetStateProperty.all(true),
            trackColor: WidgetStateProperty.all(
              scheme.onSurface.withValues(alpha: 0.08),
            ),
            trackBorderColor: WidgetStateProperty.all(
              scheme.outline.withValues(alpha: 0.35),
            ),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.dragged)) {
                return AppColors.brandSaffron;
              }
              if (states.contains(WidgetState.hovered)) {
                return AppColors.brandSaffronDeep.withValues(alpha: 0.85);
              }
              return AppColors.brandSaffronDeep.withValues(alpha: 0.55);
            }),
            crossAxisMargin: 2,
            mainAxisMargin: 0,
            interactive: true,
          ),
        ),
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 9,
          radius: const Radius.circular(8),
          interactive: true,
          child: list,
        ),
      ),
    );
  }
}
