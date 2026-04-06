import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'admin_search_bar.dart';

class AdminMenuItem {
  final String label;
  final IconData icon;
  final String route;

  const AdminMenuItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

class AdminShellLayout extends StatefulWidget {
  final String currentRoute;
  final Widget body;
  final VoidCallback onLogout;

  const AdminShellLayout({
    super.key,
    required this.currentRoute,
    required this.body,
    required this.onLogout,
  });

  static const menu = <AdminMenuItem>[
    AdminMenuItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/admin'),
    AdminMenuItem(label: 'Homepage', icon: Icons.home_work_outlined, route: '/admin/homepage'),
    AdminMenuItem(label: 'Videos', icon: Icons.play_circle_outline, route: '/admin/videos'),
    AdminMenuItem(label: 'Articles', icon: Icons.article_outlined, route: '/admin/articles'),
    AdminMenuItem(
      label: 'Explore Suggestions',
      icon: Icons.view_carousel_outlined,
      route: '/admin/explore-suggestions',
    ),
    AdminMenuItem(label: 'Categories', icon: Icons.category_outlined, route: '/admin/categories'),
    AdminMenuItem(label: 'Products', icon: Icons.inventory_2_outlined, route: '/admin/products'),
    AdminMenuItem(label: 'Product Questions', icon: Icons.question_answer_outlined, route: '/admin/product-questions'),
    AdminMenuItem(label: 'Orders', icon: Icons.receipt_long_outlined, route: '/admin/orders'),
    AdminMenuItem(label: 'Returns', icon: Icons.assignment_return_outlined, route: '/admin/returns'),
    AdminMenuItem(label: 'Users', icon: Icons.groups_outlined, route: '/admin/users'),
    AdminMenuItem(label: 'Inventory', icon: Icons.warehouse_outlined, route: '/admin/inventory'),
    AdminMenuItem(label: 'Notifications', icon: Icons.notifications_outlined, route: '/admin/notifications'),
  ];

  @override
  State<AdminShellLayout> createState() => _AdminShellLayoutState();
}

class _AdminShellLayoutState extends State<AdminShellLayout> {
  bool _showDesktopSidebar = true;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final sidebarBreakpoint = kIsWeb ? 1000.0 : 1100.0;
    final isCompact = w < sidebarBreakpoint;
    final showSidebar = !isCompact && _showDesktopSidebar;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      drawer: isCompact
          ? Drawer(
              child: SafeArea(
                child: _buildMenuList(context, closeDrawerOnTap: true),
              ),
            )
          : null,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: isCompact
                ? 'Open menu'
                : (showSidebar ? 'Hide menu' : 'Show menu'),
            icon: const Icon(Icons.menu),
            onPressed: () {
              if (isCompact) {
                Scaffold.of(ctx).openDrawer();
                return;
              }
              setState(() => _showDesktopSidebar = !_showDesktopSidebar);
            },
          ),
        ),
        title: const Text(
          'ANJANAM ADMIN',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: AdminSearchBar(),
          ),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: CircleAvatar(
              backgroundColor: AppColors.deepGold,
              child: Icon(Icons.person, color: AppColors.charcoalBlack),
            ),
          ),
          FilledButton.icon(
            onPressed: widget.onLogout,
            icon: Icon(Icons.logout, color: AppColors.charcoalBlack),
            label: Text('Logout', style: TextStyle(color: AppColors.charcoalBlack)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: AppColors.charcoalBlack,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          if (showSidebar)
            Container(
              width: 220,
              color: Colors.white,
              child: _buildMenuList(context, closeDrawerOnTap: false),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(
                isCompact
                    ? 12
                    : (kIsWeb ? 24 : 16),
              ),
              child: widget.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, {required bool closeDrawerOnTap}) {
    return ListView.builder(
      itemCount: AdminShellLayout.menu.length,
      itemBuilder: (context, index) {
        final item = AdminShellLayout.menu[index];
        final selected = item.route == widget.currentRoute;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (closeDrawerOnTap) {
                Navigator.of(context).pop();
              }
              if (!selected) {
                Navigator.of(context).pushReplacementNamed(item.route);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected ? AppColors.deepGold.withOpacity(0.14) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: selected ? AppColors.deepGold : AppColors.warmGray,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        color: selected ? AppColors.deepGold : AppColors.textDark,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
