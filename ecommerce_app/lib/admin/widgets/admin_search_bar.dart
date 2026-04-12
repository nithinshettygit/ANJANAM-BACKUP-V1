import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';

class AdminSearchBar extends ConsumerStatefulWidget {
  const AdminSearchBar({super.key});

  @override
  ConsumerState<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends ConsumerState<AdminSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final ValueNotifier<String> _overlayQuery = ValueNotifier<String>('');
  Timer? _debounce;
  OverlayEntry? _overlayEntry;

  static const _debounceMs = 200;

  double _barWidth(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    if (sw >= 1200) return 520;
    if (sw >= 900) return 460;
    if (sw >= 600) return 380;
    return (sw - 88).clamp(260.0, 360.0);
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _overlayQuery.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _clearAndClose() {
    FocusScope.of(context).unfocus();
    _controller.clear();
    _overlayQuery.value = '';
    _removeOverlay();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      if (!mounted) return;
      final trimmed = value.trim();
      _overlayQuery.value = trimmed;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (trimmed.isEmpty) {
          _removeOverlay();
        } else {
          _ensureOverlay();
        }
      });
    });
  }

  OverlayState? _resolveOverlay() {
    final nav = Navigator.maybeOf(context);
    final fromNav = nav?.overlay;
    if (fromNav != null) return fromNav;
    return Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
  }

  void _ensureOverlay() {
    if (_overlayEntry != null) return;
    final overlayState = _resolveOverlay();
    if (overlayState == null) return;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final w = _barWidth(overlayContext);
        return ValueListenableBuilder<String>(
          valueListenable: _overlayQuery,
          builder: (context, q, _) {
            if (q.isEmpty) {
              return const SizedBox.shrink();
            }
            return Consumer(
              builder: (context, ref, __) {
                final resultsAsync = ref.watch(adminGlobalSearchProvider(q));
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _clearAndClose,
                        child: const ColoredBox(color: Color(0x33000000)),
                      ),
                    ),
                    CompositedTransformFollower(
                      link: _layerLink,
                      showWhenUnlinked: false,
                      targetAnchor: Alignment.bottomLeft,
                      followerAnchor: Alignment.topLeft,
                      offset: const Offset(0, 6),
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          width: w,
                          constraints: const BoxConstraints(maxHeight: 380),
                          color: Colors.white,
                          child: _OverlayResults(
                            resultsAsync: resultsAsync,
                            onSelect: (type, id) {
                              _controller.clear();
                              _overlayQuery.value = '';
                              _removeOverlay();
                              if (type == 'product') {
                                Navigator.of(context).pushReplacementNamed('/admin/products');
                              } else if (type == 'order') {
                                Navigator.of(context).pushNamed(
                                  '/admin/orders/details/$id',
                                );
                              } else {
                                Navigator.of(context).pushNamed(
                                  '/admin/users/details/$id',
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final w = _barWidth(context);
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: w,
        height: 40,
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _clearAndClose();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search products, orders & users',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.warmGray.withOpacity(0.9),
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _clearAndClose,
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayResults extends StatelessWidget {
  final AsyncValue<List<AdminSearchResultItem>> resultsAsync;
  final void Function(String type, String id) onSelect;

  const _OverlayResults({
    required this.resultsAsync,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No matches',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoalBlack,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try another keyword. Searches title, category, SKU, brand, order id, status, and user name.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warmGray,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          );
        }
        final products = results.where((e) => e.type == 'product').toList();
        final orders = results.where((e) => e.type == 'order').toList();
        final users = results.where((e) => e.type == 'user').toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            if (products.isNotEmpty) ...[
              _SectionHeader(label: 'Products', count: products.length, icon: Icons.inventory_2_outlined),
              ...products.map((e) => _resultTile(context, e)),
            ],
            if (orders.isNotEmpty) ...[
              _SectionHeader(label: 'Orders', count: orders.length, icon: Icons.receipt_long_outlined),
              ...orders.map((e) => _resultTile(context, e)),
            ],
            if (users.isNotEmpty) ...[
              _SectionHeader(label: 'Users', count: users.length, icon: Icons.person_outline),
              ...users.map((e) => _resultTile(context, e)),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Search failed. Check your connection and try again.',
          style: TextStyle(color: AppColors.errorRed, fontSize: 13),
        ),
      ),
    );
  }

  Widget _resultTile(BuildContext context, AdminSearchResultItem item) {
    final type = item.type;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(
        type == 'product'
            ? Icons.inventory_2_outlined
            : type == 'order'
                ? Icons.receipt_long_outlined
                : Icons.person_outline,
        color: AppColors.deepGold,
        size: 22,
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.charcoalBlack,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: AppColors.warmGray.withOpacity(0.95)),
      ),
      onTap: () => onSelect(type, item.id),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.deepGold),
          const SizedBox(width: 6),
          Text(
            '$label · $count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.deepGold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
