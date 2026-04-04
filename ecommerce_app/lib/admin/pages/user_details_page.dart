import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';

import '../providers/admin_providers.dart';
import '../widgets/admin_guard.dart';
import '../widgets/admin_state_view.dart';

class AdminUserDetailsPage extends ConsumerWidget {
  final String userId;

  const AdminUserDetailsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              final detailsAsync = ref.watch(adminUserDetailsProvider(userId));
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
                              Text('Phone: ${details.phone.trim().isEmpty ? '-' : details.phone}'),
                              Text('Address: ${details.address.trim().isEmpty ? '-' : details.address}'),
                              const SizedBox(height: 8),
                              Text('Total Orders: ${details.orders.length}'),
                              Text('Total Revenue: ${formatInrAmount(details.totalRevenue)}'),
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
                              Text('Average Order Value: ${formatInrAmount(details.averageOrderValue)}'),
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
                                        DataCell(Text(formatInrAmount(o.totalAmount))),
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
