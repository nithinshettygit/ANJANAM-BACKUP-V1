import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'storefront_web_layout.dart';

/// Fixed-width storefront nav for **Flutter Web** wide layout only.
class StorefrontWebSidebar extends StatelessWidget {
  const StorefrontWebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.width = StorefrontBreakpoints.webStorefrontSidebarWidth,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final double width;

  static const List<_NavEntry> _entries = [
    _NavEntry(
      Icons.home_outlined,
      Icons.home,
      'Home',
    ),
    _NavEntry(
      Icons.storefront_outlined,
      Icons.storefront,
      'Shop',
    ),
    _NavEntry(
      Icons.explore_outlined,
      Icons.explore,
      'Explore',
    ),
    _NavEntry(
      Icons.receipt_long_outlined,
      Icons.receipt_long,
      'My Orders',
    ),
    _NavEntry(
      Icons.person_outline,
      Icons.person,
      'Account',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    assert(kIsWeb);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              right: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_mall_outlined, color: scheme.primary, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'ANJANAM',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: ListView.separated(
                    itemCount: _entries.length,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final e = _entries[index];
                      final selected = index == selectedIndex;
                      return _SidebarNavTile(
                        selected: selected,
                        icon: selected ? e.selectedIcon : e.icon,
                        label: e.label,
                        onTap: () => onDestinationSelected(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavEntry {
  const _NavEntry(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _SidebarNavTile extends StatefulWidget {
  const _SidebarNavTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.selected
        ? AppColors.brandSaffron.withValues(alpha: 0.14)
        : _hover
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.65)
            : Colors.transparent;
    final fg = widget.selected ? AppColors.brandSaffronDeep : scheme.onSurface;
    final iconColor = widget.selected ? AppColors.brandSaffronDeep : scheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          hoverColor: scheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(widget.icon, size: 22, color: iconColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
