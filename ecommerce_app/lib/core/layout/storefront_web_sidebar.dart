import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'storefront_web_layout.dart';

const double _kSidebarToggleHeight = 44;
const double _kSidebarItemGap = 7;
const double _kSidebarIconSize = 21;

/// Collapsible icon rail for **Flutter Web** wide layout only.
///
/// Default **collapsed** (64px). Toggle expands to **160px** with labels when viewport ≥
/// [StorefrontBreakpoints.webStorefrontSidebarAutoCollapseBelow].
class StorefrontWebSidebar extends StatefulWidget {
  const StorefrontWebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

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
      'Orders',
    ),
    _NavEntry(
      Icons.person_outline,
      Icons.person,
      'Account',
    ),
  ];

  @override
  State<StorefrontWebSidebar> createState() => _StorefrontWebSidebarState();
}

class _StorefrontWebSidebarState extends State<StorefrontWebSidebar> {
  /// User preference; only honored when viewport allows expansion.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    assert(kIsWeb);
    final scheme = Theme.of(context).colorScheme;
    final viewportW = MediaQuery.sizeOf(context).width;
    final canExpand =
        viewportW >= StorefrontBreakpoints.webStorefrontSidebarAutoCollapseBelow;
    final showLabels = canExpand && _expanded;
    final railW = showLabels
        ? StorefrontBreakpoints.webStorefrontSidebarWidthExpanded
        : StorefrontBreakpoints.webStorefrontSidebarWidthCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: railW,
      child: Material(
        color: scheme.surface,
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
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SidebarToggleRow(
                  expanded: showLabels,
                  canToggle: canExpand,
                  onToggle: () => setState(() => _expanded = !_expanded),
                  railWidth: railW,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: StorefrontWebSidebar._entries.length,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: _kSidebarItemGap),
                    itemBuilder: (context, index) {
                      final e = StorefrontWebSidebar._entries[index];
                      final selected = index == widget.selectedIndex;
                      return _SidebarNavTile(
                        selected: selected,
                        icon: selected ? e.selectedIcon : e.icon,
                        label: e.label,
                        showLabel: showLabels,
                        showTooltip: !showLabels,
                        iconSize: _kSidebarIconSize,
                        onTap: () => widget.onDestinationSelected(index),
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

class _SidebarToggleRow extends StatelessWidget {
  const _SidebarToggleRow({
    required this.expanded,
    required this.canToggle,
    required this.onToggle,
    required this.railWidth,
  });

  final bool expanded;
  final bool canToggle;
  final VoidCallback onToggle;
  final double railWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(
      Icons.menu_rounded,
      size: 22,
      color: scheme.onSurfaceVariant,
    );

    Widget toggle = SizedBox(
      height: _kSidebarToggleHeight,
      width: railWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canToggle ? onToggle : null,
          borderRadius: BorderRadius.circular(8),
          hoverColor: scheme.primary.withValues(alpha: 0.06),
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: icon,
                  ),
                )
              : Center(child: icon),
        ),
      ),
    );

    toggle = Tooltip(
      message: !canToggle
          ? 'Widen the window to show navigation labels'
          : (expanded ? 'Collapse sidebar' : 'Expand sidebar'),
      waitDuration: const Duration(milliseconds: 350),
      child: toggle,
    );

    return toggle;
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
    required this.showLabel,
    required this.showTooltip,
    required this.iconSize,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final bool showLabel;
  final bool showTooltip;
  final double iconSize;
  final VoidCallback onTap;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;

    final bg = selected
        ? AppColors.brandSaffron.withValues(alpha: 0.12)
        : _hover
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
            : Colors.transparent;

    final iconColor =
        selected ? AppColors.brandSaffronDeep : scheme.onSurfaceVariant;

    final fg = selected ? AppColors.brandSaffronDeep : scheme.onSurface;

    final radius = const BorderRadius.horizontal(right: Radius.circular(8));

    Widget tile = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          hoverColor: scheme.primary.withValues(alpha: 0.06),
          child: SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (selected)
                  Positioned(
                    left: 0,
                    top: 6,
                    bottom: 6,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: AppColors.brandSaffron,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: widget.showLabel
                        ? Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Icon(
                                    widget.icon,
                                    size: widget.iconSize,
                                    color: iconColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: fg,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Icon(
                              widget.icon,
                              size: widget.iconSize,
                              color: iconColor,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.showTooltip) {
      tile = Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 400),
        child: tile,
      );
    }

    return tile;
  }
}
