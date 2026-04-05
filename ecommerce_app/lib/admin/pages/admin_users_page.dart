import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';

import '../providers/admin_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    return AdminStateView(
      isLoading: usersAsync.isLoading,
      error: usersAsync.asError?.error,
      isEmpty: (usersAsync.asData?.value ?? const []).isEmpty,
      emptyMessage: 'No users found',
      child: usersAsync.when(
      data: (users) {
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          labelText: 'Search users',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    DropdownButton<String>(
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
