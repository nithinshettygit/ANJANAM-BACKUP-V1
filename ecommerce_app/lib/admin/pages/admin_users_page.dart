import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';

import '../utils/admin_android_ui.dart';
import '../providers/admin_providers.dart';
import '../providers/is_admin_provider.dart';
import '../services/admin_service.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_state_view.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  String _query = '';
  String _sortBy = 'Total Spent (High to Low)';
  final Set<String> _pendingUserIds = <String>{};
  final Set<String> _pendingRoleUserIds = <String>{};

  Future<void> _toggleBlock(AdminUserRow user) async {
    if (_pendingUserIds.contains(user.id)) return;
    final role = user.role.trim().toLowerCase();
    if (role == 'super_admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Super admin accounts cannot be blocked.')),
      );
      return;
    }
    final shouldBlock = user.status != 'blocked';
    String? reason;
    if (shouldBlock) {
      final reasonController = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Block ${user.fullName}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Blocked users cannot sign in or perform account actions.',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Block'),
              ),
            ],
          );
        },
      );
      if (proceed != true) {
        reasonController.dispose();
        return;
      }
      reason = reasonController.text.trim();
      reasonController.dispose();
    }

    setState(() => _pendingUserIds.add(user.id));
    try {
      await ref.read(adminUserBlockActionProvider.notifier).setBlocked(
            user.id,
            blocked: shouldBlock,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldBlock
                ? 'User blocked successfully.'
                : 'User unblocked successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _pendingUserIds.remove(user.id));
      }
    }
  }

  Future<void> _toggleAdminRole(AdminUserRow user) async {
    if (_pendingRoleUserIds.contains(user.id)) return;
    final role = user.role.trim().toLowerCase();
    if (role == 'super_admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Super admin role cannot be changed here.')),
      );
      return;
    }
    final promote = role != 'admin';
    final actionLabel = promote ? 'Promote to Admin' : 'Remove Admin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel?'),
        content: Text(
          promote
              ? 'This user will get admin access to products, orders, and user management.'
              : 'This user will be reverted to customer access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _pendingRoleUserIds.add(user.id));
    try {
      await ref.read(adminUserRoleActionProvider.notifier).setRole(
            user.id,
            role: promote ? 'admin' : 'customer',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            promote ? 'User promoted to admin.' : 'Admin access removed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _pendingRoleUserIds.remove(user.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final isSuperAdminAsync = ref.watch(isSuperAdminProvider);
    final canManageRoles = isSuperAdminAsync.asData?.value == true;
    return AdminStateView(
      isLoading: usersAsync.isLoading,
      error: usersAsync.asError?.error,
      isEmpty: (usersAsync.asData?.value ?? const []).isEmpty,
      emptyMessage: 'No users found',
      child: usersAsync.when(
      data: (users) {
        final compact = kAdminAndroidCompactChrome;
        final denseWeb = !compact;
        final filtered = users.where((u) {
          final q = _query.trim().toLowerCase();
          if (q.isEmpty) return true;
          return u.fullName.toLowerCase().contains(q) || u.id.toLowerCase().contains(q);
        }).toList();
        filtered.sort((a, b) {
          if (_sortBy == 'Total Orders (High to Low)') {
            return b.totalOrders.compareTo(a.totalOrders);
          }
          return b.totalSpent.compareTo(a.totalSpent);
        });

        return Column(
          children: [
            Card(
              margin: compact ? EdgeInsets.zero : null,
              child: Padding(
                padding: denseWeb
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                    : const EdgeInsets.all(12),
                child: Wrap(
                  spacing: denseWeb ? 8 : 10,
                  runSpacing: denseWeb ? 8 : 10,
                  children: [
                    SizedBox(
                      width: denseWeb ? 220 : 260,
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          labelText: 'Search users',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      isDense: denseWeb,
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(
                          value: 'Total Spent (High to Low)',
                          child: Text('Sort by spent'),
                        ),
                        DropdownMenuItem(
                          value: 'Total Orders (High to Low)',
                          child: Text('Sort by orders'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => ref.invalidate(adminUsersProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AdminDataTable<AdminUserRow>(
                rows: filtered,
                emptyMessage: 'No users found',
                columns: [
                  AdminTableColumn<AdminUserRow>(
                    label: 'User Name',
                    sortValue: (u) => u.fullName,
                    cellBuilder: (u) => Text(u.fullName),
                  ),
                  AdminTableColumn<AdminUserRow>(
                    label: 'Email',
                    sortValue: (u) => u.email,
                    cellBuilder: (u) => Text(u.email),
                  ),
                  AdminTableColumn<AdminUserRow>(
                    label: 'Total Orders',
                    sortValue: (u) => u.totalOrders,
                    cellBuilder: (u) => Text(u.totalOrders.toString()),
                  ),
                  AdminTableColumn<AdminUserRow>(
                    label: 'Total Spent',
                    sortValue: (u) => u.totalSpent,
                    cellBuilder: (u) => Text(
                      formatInrAmount(u.totalSpent),
                      style: const TextStyle(
                        color: AppColors.priceText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AdminTableColumn<AdminUserRow>(
                    label: 'Status',
                    sortValue: (u) => u.status,
                    cellBuilder: (u) => Chip(
                      label: Text(
                        u.status == 'blocked' ? 'Blocked' : 'Active',
                      ),
                      backgroundColor: u.status == 'blocked'
                          ? Colors.red.withOpacity(0.14)
                          : Colors.green.withOpacity(0.14),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  AdminTableColumn<AdminUserRow>(
                    label: 'Role',
                    sortValue: (u) => u.role,
                    cellBuilder: (u) {
                      final role = u.role.toLowerCase();
                      final label = switch (role) {
                        'super_admin' => 'Super Admin',
                        'admin' => 'Admin',
                        _ => 'Customer',
                      };
                      final color = switch (role) {
                        'super_admin' => Colors.purple,
                        'admin' => Colors.blue,
                        _ => Colors.grey,
                      };
                      return Chip(
                        label: Text(label),
                        backgroundColor: color.withOpacity(0.14),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                  AdminTableColumn<AdminUserRow>(
                    label: 'Role Action',
                    cellBuilder: (u) {
                      if (!canManageRoles) {
                        return const Text('Super admin only');
                      }
                      final role = u.role.toLowerCase();
                      final pending = _pendingRoleUserIds.contains(u.id);
                      if (role == 'super_admin') {
                        return const Text('Protected');
                      }
                      final promote = role != 'admin';
                      return FilledButton.tonal(
                        onPressed: pending ? null : () => _toggleAdminRole(u),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 34),
                          backgroundColor: promote
                              ? Colors.blue.withOpacity(0.18)
                              : Colors.orange.withOpacity(0.20),
                          foregroundColor: AppColors.charcoalBlack,
                        ),
                        child: Text(
                          pending
                              ? 'Please wait...'
                              : (promote ? 'Promote Admin' : 'Remove Admin'),
                        ),
                      );
                    },
                  ),
                  AdminTableColumn<AdminUserRow>(
                    label: 'Action',
                    cellBuilder: (u) {
                      final pending = _pendingUserIds.contains(u.id);
                      final isBlocked = u.status == 'blocked';
                      final role = u.role.trim().toLowerCase();
                      if (role == 'super_admin') {
                        return const Text('Protected');
                      }
                      if (role == 'admin' && !canManageRoles) {
                        return const Text('Super admin only');
                      }
                      return FilledButton.tonal(
                        onPressed: pending ? null : () => _toggleBlock(u),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(98, 34),
                          backgroundColor: isBlocked
                              ? Colors.green.withOpacity(0.18)
                              : Colors.red.withOpacity(0.18),
                          foregroundColor: AppColors.charcoalBlack,
                        ),
                        child: Text(
                          pending
                              ? 'Please wait...'
                              : (isBlocked ? 'Unblock' : 'Block'),
                        ),
                      );
                    },
                  ),
                  AdminTableColumn<AdminUserRow>(
                    label: 'View',
                    cellBuilder: (u) => FilledButton.tonal(
                      onPressed: () => Navigator.of(context).pushNamed(
                        '/admin/users/details',
                        arguments: u.id,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(90, 34),
                        backgroundColor: AppColors.deepGold.withOpacity(0.18),
                        foregroundColor: AppColors.charcoalBlack,
                      ),
                      child: const Text('Details'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    ),
    );
  }
}
