import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../utils/admin_order_status_workflow.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_state_view.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  static const _kOrderStatusFilters = <(String value, String label)>[
    ('all', 'All'),
    ('pending_payment', 'Pending payment'),
    ('payment_failed', 'Payment failed'),
    ('processing', 'Processing'),
    ('packed', 'Packed'),
    ('shipped', 'Shipped'),
    ('out_for_delivery', 'Out for delivery'),
    ('delivered', 'Delivered'),
    ('cancel_requested', 'Cancel requested'),
    ('cancelled', 'Cancelled'),
  ];

  String _statusFilter = 'all';
  DateTimeRange? _dateRange;
  final Set<String> _updatingOrderIds = {};
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scheduleAdminSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final next = value.trim();
      final cur = ref.read(adminOrderSearchQueryProvider).trim();
      if (next == cur) return;
      ref.read(adminOrderSearchQueryProvider.notifier).set(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    return AdminStateView(
      isLoading: ordersAsync.isLoading,
      error: ordersAsync.asError?.error,
      isEmpty: false,
      emptyMessage: 'No orders found',
      child: ordersAsync.when(
      data: (orders) {
        final filtered = orders.where((o) {
          final statusOk = _statusFilter == 'all' ||
              canonicalAdminOrderStatus(o.status) == _statusFilter;
          final dateOk = _dateRange == null ||
              (o.createdAt.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
                  o.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1))));
          return statusOk && dateOk;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SearchBar(
                controller: _searchCtrl,
                hintText:
                    'Search order id, customer, email, status, product title…',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _searchDebounce?.cancel();
                        ref.read(adminOrderSearchQueryProvider.notifier).set('');
                        setState(() {});
                      },
                    ),
                ],
                onChanged: (v) {
                  _scheduleAdminSearch(v);
                  setState(() {});
                },
                onSubmitted: (v) {
                  _searchDebounce?.cancel();
                  ref.read(adminOrderSearchQueryProvider.notifier).set(v.trim());
                },
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    DropdownButton<String>(
                      value: _kOrderStatusFilters.any((e) => e.$1 == _statusFilter)
                          ? _statusFilter
                          : 'all',
                      items: _kOrderStatusFilters
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e.$1,
                              child: Text('Status: ${e.$2}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final selected = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _dateRange,
                        );
                        if (selected != null) {
                          setState(() => _dateRange = selected);
                        }
                      },
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        _dateRange == null
                            ? 'Date Range'
                            : '${_dateRange!.start.toLocal().toString().split(' ').first} - '
                                '${_dateRange!.end.toLocal().toString().split(' ').first}',
                      ),
                    ),
                    if (_dateRange != null)
                      TextButton(
                        onPressed: () => setState(() => _dateRange = null),
                        child: const Text('Clear Date'),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: () => ref.invalidate(adminOrdersProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Tip: scroll horizontally to view all columns, including Actions.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
            Expanded(
              child: AdminDataTable<AdminOrderRow>(
                rows: filtered,
                emptyMessage: 'No orders found',
                minTableWidth: 1560,
                columns: [
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Order ID',
                    sortValue: (o) => o.id,
                    cellBuilder: (o) => Text(o.id),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Customer',
                    sortValue: (o) => o.customerName,
                    cellBuilder: (o) => Text(o.customerName),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Items',
                    sortValue: (o) => o.itemsSubtotal,
                    cellBuilder: (o) => Text(formatInrAmount(o.itemsSubtotal)),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Delivery',
                    sortValue: (o) => o.deliveryFee,
                    cellBuilder: (o) => Text(
                      o.deliveryFee <= 0 ? 'FREE' : formatInrAmount(o.deliveryFee),
                    ),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Order total',
                    sortValue: (o) => o.totalAmount,
                    cellBuilder: (o) => Text(formatInrAmount(o.totalAmount)),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Order Status',
                    sortValue: (o) => o.status,
                    cellBuilder: (o) => _statusBadge(o.status),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Payment',
                    sortValue: (o) => o.paymentStatus,
                    cellBuilder: (o) => _paymentStatusBadge(o.paymentStatus),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Date',
                    sortValue: (o) => o.createdAt,
                    cellBuilder: (o) => Text(
                      formatOrderDetailsDateTime(o.createdAt.toLocal()),
                    ),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Actions',
                    cellBuilder: (o) => _orderActionMenu(o),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'View Details',
                    cellBuilder: (o) => FilledButton.tonal(
                      onPressed: () => Navigator.of(context).pushNamed(
                        '/admin/orders/details',
                        arguments: o.id,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(90, 34),
                        backgroundColor: AppColors.deepGold.withOpacity(0.18),
                        foregroundColor: AppColors.charcoalBlack,
                      ),
                      child: const Text('View'),
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

  Widget _orderActionMenu(AdminOrderRow order) {
    final isUpdating = _updatingOrderIds.contains(order.id);
    final actions = adminOrderNextActions(order.status);
    return PopupMenuButton<AdminOrderNextAction>(
      tooltip: 'Update order status',
      enabled: !isUpdating && actions.isNotEmpty,
      onSelected: (a) => _applyOrderAction(order.id, a),
      itemBuilder: (_) {
        if (actions.isEmpty) {
          return [
            const PopupMenuItem<AdminOrderNextAction>(
              enabled: false,
              child: Text('No status changes allowed'),
            ),
          ];
        }
        return actions
            .map(
              (a) => PopupMenuItem<AdminOrderNextAction>(
                value: a,
                child: Text(
                  a.buttonLabel,
                  style: TextStyle(
                    color: a.destructive ? Colors.red.shade800 : null,
                    fontWeight: a.destructive ? FontWeight.w600 : null,
                  ),
                ),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
        ),
        child: Text(
          isUpdating ? 'Updating...' : 'Actions',
          style: TextStyle(
            color: isUpdating ? Colors.grey : Colors.blueGrey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final c = canonicalAdminOrderStatus(status);
    final Color color;
    switch (c) {
      case 'pending_payment':
        color = Colors.orange;
        break;
      case 'payment_failed':
        color = Colors.deepOrange.shade700;
        break;
      case 'processing':
        color = Colors.deepPurple;
        break;
      case 'packed':
        color = Colors.indigo;
        break;
      case 'shipped':
        color = Colors.blue;
        break;
      case 'out_for_delivery':
        color = Colors.teal;
        break;
      case 'delivered':
        color = Colors.green;
        break;
      case 'cancel_requested':
        color = Colors.deepPurpleAccent;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(_orderStatusDisplayLabel(c)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }

  String _orderStatusDisplayLabel(String canonical) {
    switch (canonical) {
      case 'pending_payment':
        return 'Pending payment';
      case 'payment_failed':
        return 'Payment failed';
      case 'processing':
        return 'Processing';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'Shipped';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancel_requested':
        return 'Cancel requested';
      case 'cancelled':
        return 'Cancelled';
      default:
        return canonical;
    }
  }

  Widget _paymentStatusBadge(String raw) {
    final s = raw.toLowerCase().trim();
    late Color color;
    late String label;
    switch (s) {
      case 'paid':
        color = Colors.green.shade700;
        label = 'Paid';
        break;
      case 'failed':
        color = Colors.red.shade700;
        label = 'Failed';
        break;
      default:
        color = Colors.orange.shade800;
        label = 'Pending';
    }
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }

  Future<void> _applyOrderAction(String orderId, AdminOrderNextAction action) async {
    final noteOutcome = await showAdminOrderStatusConfirmDialog(
      context,
      action: action,
    );
    if (!mounted || noteOutcome == null) return;

    setState(() => _updatingOrderIds.add(orderId));
    try {
      await ref.read(adminServiceProvider).updateOrderStatus(
            orderId: orderId,
            status: action.targetStatusTitleCase,
            notes: noteOutcome.isEmpty ? null : noteOutcome,
          );
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(adminOrderDetailsProvider(orderId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(adminOrderActionSuccessMessage(action))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingOrderIds.remove(orderId));
      }
    }
  }

}
