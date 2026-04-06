import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';

import '../providers/admin_providers.dart';
import '../providers/is_admin_provider.dart';
import '../services/admin_service.dart';
import '../widgets/admin_guard.dart';
import '../widgets/admin_state_view.dart';

class AdminUserDetailsPage extends ConsumerStatefulWidget {
  final String userId;

  const AdminUserDetailsPage({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends ConsumerState<AdminUserDetailsPage> {
  bool _isUpdatingStatus = false;
  bool _isUpdatingRole = false;

  Future<void> _toggleUserBlock(AdminUserRow user) async {
    if (_isUpdatingStatus) return;
    final shouldBlock = user.status != 'blocked';
    String? reason;
    if (shouldBlock) {
      final reasonController = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
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
        ),
      );
      if (proceed != true) {
        reasonController.dispose();
        return;
      }
      reason = reasonController.text.trim();
      reasonController.dispose();
    }

    setState(() => _isUpdatingStatus = true);
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
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _toggleUserRole(AdminUserRow user) async {
    if (_isUpdatingRole) return;
    final role = user.role.trim().toLowerCase();
    if (role == 'super_admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Super admin role cannot be changed here.')),
      );
      return;
    }
    final promote = role != 'admin';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(promote ? 'Promote to Admin?' : 'Remove Admin?'),
        content: Text(
          promote
              ? 'This user will gain admin dashboard access.'
              : 'This user will return to customer access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(promote ? 'Promote' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isUpdatingRole = true);
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
        setState(() => _isUpdatingRole = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customer Details'),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/users'),
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(
            builder: (_) {
              final detailsAsync = ref.watch(adminUserDetailsProvider(widget.userId));
              final isSuperAdminAsync = ref.watch(isSuperAdminProvider);
              final canManageRoles = isSuperAdminAsync.asData?.value == true;
              final detailsValue = detailsAsync.asData?.value;
              return AdminStateView(
                isLoading: detailsAsync.isLoading,
                error: detailsAsync.asError?.error,
                isEmpty: detailsAsync.hasValue && detailsValue == null,
                emptyMessage: 'User not found',
                child: detailsAsync.when(
                  data: (details) {
                  if (details == null) {
                    return const SizedBox.shrink();
                  }
                  final user = details.user;
                  return ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text('Customer Name: ${user.fullName}'),
                              Text('Email: ${user.email}'),
                              Text(
                                'Role: ${() {
                                  final role = user.role.toLowerCase();
                                  if (role == 'super_admin') return 'Super Admin';
                                  if (role == 'admin') return 'Admin';
                                  return 'Customer';
                                }()}',
                              ),
                              Text('Phone: ${details.phone.trim().isEmpty ? '-' : details.phone}'),
                              Text('Address: ${details.address.trim().isEmpty ? '-' : details.address}'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      user.status == 'blocked' ? 'Blocked' : 'Active',
                                    ),
                                    backgroundColor: user.status == 'blocked'
                                        ? Colors.red.withOpacity(0.14)
                                        : Colors.green.withOpacity(0.14),
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonal(
                                    onPressed: _isUpdatingStatus ? null : () => _toggleUserBlock(user),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: user.status == 'blocked'
                                          ? Colors.green.withOpacity(0.18)
                                          : Colors.red.withOpacity(0.18),
                                      foregroundColor: AppColors.charcoalBlack,
                                    ),
                                    child: Text(
                                      _isUpdatingStatus
                                          ? 'Updating...'
                                          : (user.status == 'blocked' ? 'Unblock user' : 'Block user'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (canManageRoles)
                                    FilledButton.tonal(
                                      onPressed: _isUpdatingRole ? null : () => _toggleUserRole(user),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: user.role.toLowerCase() == 'admin'
                                            ? Colors.orange.withOpacity(0.20)
                                            : Colors.blue.withOpacity(0.18),
                                        foregroundColor: AppColors.charcoalBlack,
                                      ),
                                      child: Text(
                                        _isUpdatingRole
                                            ? 'Updating role...'
                                            : (user.role.toLowerCase() == 'admin'
                                                ? 'Remove Admin'
                                                : (user.role.toLowerCase() == 'super_admin'
                                                    ? 'Super Admin'
                                                    : 'Promote Admin')),
                                      ),
                                    ),
                                ],
                              ),
                              if (user.status == 'blocked' &&
                                  user.blockedReason != null &&
                                  user.blockedReason!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Blocked Reason: ${user.blockedReason}'),
                              ],
                              const SizedBox(height: 8),
                              Text('Total Orders: ${details.orders.length}'),
                              Text.rich(
                                TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  children: [
                                    const TextSpan(text: 'Total Revenue: '),
                                    TextSpan(
                                      text: formatInrAmount(details.totalRevenue),
                                      style: const TextStyle(
                                        color: AppColors.priceText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Last Order Date: ${_formatDateTime(details.lastOrderDate)}',
                              ),
                              Text(
                                'Account Created: ${user.createdAt?.toLocal().toString().split('.').first ?? '-'}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Insights',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text('First Order Date: ${_formatDateTime(details.firstOrderDate)}'),
                              Text.rich(
                                TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  children: [
                                    const TextSpan(text: 'Average Order Value: '),
                                    TextSpan(
                                      text: formatInrAmount(details.averageOrderValue),
                                      style: const TextStyle(
                                        color: AppColors.priceText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order History',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Order ID')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Total')),
                                    DataColumn(label: Text('Open')),
                                  ],
                                  rows: details.orders.map((o) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(o.id)),
                                        DataCell(Text(o.createdAt.toLocal().toString().split('.').first)),
                                        DataCell(Text(o.status)),
                                        DataCell(
                                          Text(
                                            formatInrAmount(o.totalAmount),
                                            style: const TextStyle(
                                              color: AppColors.priceText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          InkWell(
                                            onTap: () => Navigator.of(context).pushNamed(
                                              '/admin/orders/details',
                                              arguments: o.id,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 4,
                                              ),
                                              child: Text(
                                                'View',
                                                style: TextStyle(
                                                  color: AppColors.charcoalBlack,
                                                  fontWeight: FontWeight.w600,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: AppColors.deepGold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '-';
  return dateTime.toLocal().toString().split('.').first;
}
