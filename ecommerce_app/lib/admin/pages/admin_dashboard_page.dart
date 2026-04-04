import 'package:ecommerce_app/core/layout/storefront_web_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_orders_chart.dart';
import '../widgets/admin_revenue_chart.dart';
import '../widgets/admin_state_view.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int _selectedDays = 7;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(adminDashboardProvider);
    final analyticsAsync = ref.watch(adminDashboardAnalyticsProvider(_selectedDays));
    final loading = summaryAsync.isLoading || analyticsAsync.isLoading;
    final error = summaryAsync.asError?.error ?? analyticsAsync.asError?.error;

    return AdminStateView(
      isLoading: loading,
      error: error,
      isEmpty: false,
      emptyMessage: 'No dashboard data available',
      child: summaryAsync.when(
        data: (summary) => analyticsAsync.when(
          data: (analytics) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    kIsWeb && constraints.maxWidth > StorefrontBreakpoints.tablet;
                final sectionGap = wide ? 20.0 : 12.0;
                final statGap = wide ? 20.0 : 16.0;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: wide ? 26 : 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              ref.invalidate(adminDashboardProvider);
                              ref.invalidate(
                                adminDashboardAnalyticsProvider(_selectedDays),
                              );
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatCard(
                            title: 'Total Products',
                            value: summary.totalProducts.toString(),
                          ),
                          _StatCard(
                            title: 'Total Orders',
                            value: summary.totalOrders.toString(),
                          ),
                          _StatCard(
                            title: 'Total Users',
                            value: summary.totalUsers.toString(),
                          ),
                          _StatCard(
                            title: 'Total Revenue',
                            value: formatInrAmount(summary.totalRevenue),
                          ),
                        ],
                      ),
                      SizedBox(height: statGap),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatCard(
                            title: 'Revenue Today',
                            value: formatInrAmount(analytics.revenueToday),
                          ),
                          _StatCard(
                            title: 'Revenue This Month',
                            value: formatInrAmount(analytics.revenueThisMonth),
                          ),
                          _StatCard(
                            title: 'Total Orders',
                            value: analytics.totalOrders.toString(),
                          ),
                          _StatCard(
                            title: 'Pending Orders',
                            value: analytics.pendingOrders.toString(),
                          ),
                          _StatCard(
                            title: 'Total Customers',
                            value: analytics.totalCustomers.toString(),
                          ),
                          _StatCard(
                            title: 'Average Order Value',
                            value: formatInrAmount(analytics.averageOrderValue),
                          ),
                        ],
                      ),
                      SizedBox(height: statGap),
                      Row(
                        children: [
                          const Text(
                            'Window:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Last 7 days'),
                            selected: _selectedDays == 7,
                            onSelected: (_) => setState(() => _selectedDays = 7),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Last 30 days'),
                            selected: _selectedDays == 30,
                            onSelected: (_) => setState(() => _selectedDays = 30),
                          ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AdminRevenueChart(
                                points: analytics.revenueTrend,
                                title: 'Revenue Trend ($_selectedDays days)',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AdminOrdersChart(points: analytics.ordersPerDay),
                            ),
                          ],
                        )
                      else ...[
                        AdminRevenueChart(
                          points: analytics.revenueTrend,
                          title: 'Revenue Trend ($_selectedDays days)',
                        ),
                        SizedBox(height: sectionGap),
                        AdminOrdersChart(points: analytics.ordersPerDay),
                      ],
                      SizedBox(height: sectionGap),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(wide ? 18 : 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top Selling Products',
                                style: TextStyle(
                                  fontSize: wide ? 18 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: wide ? 12 : 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    AppColors.deepGold.withOpacity(0.08),
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Product')),
                                    DataColumn(label: Text('Quantity Sold')),
                                    DataColumn(label: Text('Revenue')),
                                  ],
                                  rows: analytics.topSellingProducts.map((p) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(p.title)),
                                        DataCell(Text(p.quantitySold.toString())),
                                        DataCell(Text(formatInrAmount(p.revenue))),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(wide ? 18 : 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent Orders',
                                style: TextStyle(
                                  fontSize: wide ? 20 : 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: wide ? 14 : 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    AppColors.deepGold.withOpacity(0.08),
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Order ID')),
                                    DataColumn(label: Text('Customer')),
                                    DataColumn(label: Text('Order total')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Date')),
                                  ],
                                  rows: summary.recentOrders.isEmpty
                                      ? const [
                                          DataRow(
                                            cells: [
                                              DataCell(Text('-')),
                                              DataCell(Text('No recent orders')),
                                              DataCell(Text('-')),
                                              DataCell(Text('-')),
                                              DataCell(Text('-')),
                                            ],
                                          ),
                                        ]
                                      : summary.recentOrders.map((order) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(order.id)),
                                              DataCell(Text(order.customerName)),
                                              DataCell(
                                                Text(formatInrAmount(order.totalAmount)),
                                              ),
                                              DataCell(Text(order.status)),
                                              DataCell(
                                                Text(_formatDateTime(order.createdAt)),
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
                  ),
                );
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year.toString();
    final hour24 = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final hour = hour12.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute $period';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.warmGray)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
