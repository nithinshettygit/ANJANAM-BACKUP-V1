import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show RealtimeChannel, PostgresChangeEvent;

import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';

import '../utils/admin_android_ui.dart';
import '../../features/notifications/data/services/fcm_edge_function_notification_sender.dart';
import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../utils/admin_order_status_push.dart';
import '../utils/admin_order_status_workflow.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_state_view.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  static const _kSearchDebounce = Duration(milliseconds: 500);

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
    ('cancel_rejected', 'Cancel rejected'),
    ('cancelled', 'Cancelled'),
  ];

  String _statusFilter = 'all';
  DateTimeRange? _dateRange;
  final Set<String> _updatingOrderIds = {};
  final Set<String> _refundingOrderIds = {};
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  RealtimeChannel? _ordersRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _subscribeOrdersRealtime();
  }

  @override
  void dispose() {
    if (_ordersRealtimeChannel != null) {
      ref.read(supabaseClientProvider).removeChannel(_ordersRealtimeChannel!);
      _ordersRealtimeChannel = null;
    }
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _invalidateOrderDetailsFromPayload(dynamic payload) {
    try {
      final nr = (payload as dynamic).newRecord;
      final or = (payload as dynamic).oldRecord;
      String? id;
      if (nr is Map) id = nr['id']?.toString();
      if ((id == null || id.isEmpty) && or is Map) id = or['id']?.toString();
      if (id != null && id.isNotEmpty) {
        ref.invalidate(adminOrderDetailsProvider(id));
      }
    } catch (_) {}
  }

  void _subscribeOrdersRealtime() {
    final client = ref.read(supabaseClientProvider);
    final channel = client.channel('admin-orders-live');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        if (!mounted) return;
        _invalidateOrderDetailsFromPayload(payload);
        ref.invalidate(adminOrdersProvider);
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        if (!mounted) return;
        _invalidateOrderDetailsFromPayload(payload);
        ref.invalidate(adminOrdersProvider);
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        if (!mounted) return;
        _invalidateOrderDetailsFromPayload(payload);
        ref.invalidate(adminOrdersProvider);
      },
    );
    channel.subscribe();
    _ordersRealtimeChannel = channel;
  }

  void _scheduleAdminSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      final next = value.trim();
      final cur = ref.read(adminOrderSearchQueryProvider).trim();
      if (next == cur) return;
      ref.read(adminOrderSearchQueryProvider.notifier).set(next);
    });
  }

  /// Same pattern as products/inventory: [TextField] + debounced server query; no full-page reload on each keystroke.
  Widget _ordersSearchTextField({
    required bool compact,
    required bool denseWeb,
  }) {
    return ListenableBuilder(
      listenable: _searchCtrl,
      builder: (context, _) {
        final hasText = _searchCtrl.text.isNotEmpty;
        return TextField(
          controller: _searchCtrl,
          onChanged: _scheduleAdminSearch,
          onSubmitted: (v) {
            _searchDebounce?.cancel();
            ref.read(adminOrderSearchQueryProvider.notifier).set(v.trim());
          },
          decoration: InputDecoration(
            labelText: compact ? null : 'Search orders',
            hintText: compact
                ? 'Search orders…'
                : 'order id, customer, email, status, product title…',
            prefixIcon: Icon(Icons.search, size: denseWeb ? 20 : 22),
            suffixIcon: hasText
                ? IconButton(
                    icon: Icon(Icons.clear, size: denseWeb ? 20 : 22),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchCtrl.clear();
                      _searchDebounce?.cancel();
                      ref.read(adminOrderSearchQueryProvider.notifier).set('');
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    return AdminStateView(
      isLoading: ordersAsync.isLoading && !ordersAsync.hasValue,
      error: ordersAsync.hasError && !ordersAsync.hasValue ? ordersAsync.error : null,
      isEmpty: false,
      emptyMessage: 'No orders found',
      child: ordersAsync.when(
      skipLoadingOnReload: false,
      data: (orders) {
        final filtered = orders.where((o) {
          final statusOk = _statusFilter == 'all' ||
              canonicalAdminOrderStatus(o.status) == _statusFilter;
          final dateOk = _dateRange == null ||
              (o.createdAt.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
                  o.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1))));
          return statusOk && dateOk;
        }).toList();

        final theme = Theme.of(context);
        final compact = kAdminAndroidCompactChrome;
        final denseWeb = !compact && kIsWeb;
        final showInlineTopBar = denseWeb;

        return Column(
          children: [
            Card(
              margin: compact ? EdgeInsets.zero : null,
              child: Padding(
                padding: denseWeb
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                    : adminFilterCardPadding,
                child: showInlineTopBar
                    ? Row(
                        children: [
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 40, maxHeight: 44),
                              child: _ordersSearchTextField(compact: false, denseWeb: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String>(
                            isDense: true,
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
                          const SizedBox(width: 8),
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
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                          if (_dateRange != null) ...[
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () => setState(() => _dateRange = null),
                              child: const Text('Clear'),
                            ),
                          ],
                          const SizedBox(width: 4),
                          FilledButton.tonalIcon(
                            onPressed: () => ref.invalidate(adminOrdersProvider),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: denseWeb ? 760 : double.infinity,
                                minHeight: compact || denseWeb ? 40 : 52,
                                maxHeight: compact || denseWeb ? 44 : 56,
                              ),
                              child: _ordersSearchTextField(compact: compact, denseWeb: denseWeb),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: compact ? 6 : (denseWeb ? 8 : 10),
                            runSpacing: compact ? 6 : (denseWeb ? 8 : 10),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DropdownButton<String>(
                                isDense: compact,
                                value: _kOrderStatusFilters.any((e) => e.$1 == _statusFilter)
                                    ? _statusFilter
                                    : 'all',
                                items: _kOrderStatusFilters
                                    .map(
                                      (e) => DropdownMenuItem<String>(
                                        value: e.$1,
                                        child: Text(
                                          compact ? e.$2 : 'Status: ${e.$2}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                              ),
                              if (compact)
                                IconButton(
                                  tooltip: _dateRange == null
                                      ? 'Date range'
                                      : '${_dateRange!.start.toLocal().toString().split(' ').first} – '
                                          '${_dateRange!.end.toLocal().toString().split(' ').first}',
                                  icon: Icon(
                                    Icons.date_range_outlined,
                                    color: _dateRange != null ? theme.colorScheme.primary : null,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  style: IconButton.styleFrom(
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
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
                                )
                              else
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
                                  style: OutlinedButton.styleFrom(
                                    visualDensity:
                                        denseWeb ? VisualDensity.compact : VisualDensity.standard,
                                    minimumSize: denseWeb ? const Size(0, 34) : null,
                                    padding: denseWeb
                                        ? const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          )
                                        : null,
                                  ),
                                ),
                              if (_dateRange != null)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity:
                                        compact ? VisualDensity.compact : VisualDensity.standard,
                                    padding: compact
                                        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
                                        : null,
                                    tapTargetSize: compact
                                        ? MaterialTapTargetSize.shrinkWrap
                                        : null,
                                  ),
                                  onPressed: () => setState(() => _dateRange = null),
                                  child: Text(compact ? 'Clear' : 'Clear Date'),
                                ),
                              if (compact)
                                adminAndroidToolbarIconButton(
                                  icon: Icons.refresh,
                                  tooltip: 'Refresh',
                                  onPressed: () => ref.invalidate(adminOrdersProvider),
                                )
                              else
                                FilledButton.tonalIcon(
                                  onPressed: () => ref.invalidate(adminOrdersProvider),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                  style: FilledButton.styleFrom(
                                    visualDensity:
                                        denseWeb ? VisualDensity.compact : VisualDensity.standard,
                                    minimumSize: denseWeb ? const Size(0, 34) : null,
                                    padding: denseWeb
                                        ? const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          )
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: denseWeb ? 4 : 6),
            if (!compact)
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
                initialRowsPerPage: denseWeb ? 20 : 10,
                emptyMessage: 'No orders found',
                minTableWidth: 1560,
                columns: [
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Order ID',
                    sortValue: (o) => o.id,
                    cellBuilder: (o) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.id),
                        if (o.orderKind.toLowerCase() == 'replacement')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text('Replacement'),
                                  backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
                                  side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.35)),
                                  labelStyle: TextStyle(
                                    color: Colors.deepPurple.shade700,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                if ((o.originalOrderId ?? '').isNotEmpty)
                                  Text(
                                    'From: ${o.originalOrderId}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Customer',
                    sortValue: (o) => o.customerName,
                    cellBuilder: (o) => Text(o.customerName),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Total Amount',
                    sortValue: (o) => o.totalAmount,
                    cellBuilder: (o) => Text(
                      formatInrAmount(o.totalAmount),
                      style: const TextStyle(
                        color: AppColors.priceText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Payment Method',
                    sortValue: (o) => o.paymentMethod,
                    cellBuilder: (o) => _paymentMethodBadge(o.paymentMethod),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Payment Status',
                    sortValue: (o) => o.paymentStatus,
                    cellBuilder: (o) => _paymentStatusBadge(o.paymentStatus),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Order Status',
                    sortValue: (o) => o.status,
                    cellBuilder: (o) => _statusBadge(o.status),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Delivery Mode',
                    sortValue: (o) => (o.deliveryMethod ?? '').toLowerCase(),
                    cellBuilder: (o) => _deliveryModeBadge(o),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Delivery Status',
                    sortValue: (o) =>
                        (o.deliveryStatus ?? o.shipmentStatus ?? '').toLowerCase(),
                    cellBuilder: (o) => _deliveryStatusBadge(
                      o.deliveryStatus,
                      o.shipmentStatus,
                    ),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Refund Status',
                    sortValue: (o) => o.refundStatus,
                    cellBuilder: (o) => _refundStatusBadge(o),
                  ),
                  AdminTableColumn<AdminOrderRow>(
                    label: 'Created At',
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
                        '/admin/orders/details/${o.id}',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(90, 34),
                        backgroundColor: AppColors.deepGold.withValues(alpha: 0.18),
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
    final actions = adminOrderNextActions(
      order.status,
      paymentMethodRaw: order.paymentMethod,
    );
    final isRefunding = _refundingOrderIds.contains(order.id);
    final canRefund = _canInitiateRefund(order);
    final refundStatus = order.refundStatus.toLowerCase().trim();
    final refundLabel = refundStatus == 'processing'
        ? 'Refund Processing'
        : refundStatus == 'refunded'
            ? 'Refund Completed'
            : 'Initiate Refund';
    final isCod = order.paymentMethod.toLowerCase().trim() == 'cod';
    return PopupMenuButton<String>(
      tooltip: 'Order actions',
      enabled: !(isUpdating || isRefunding),
      onSelected: (value) async {
        if (value.startsWith('status:')) {
          final idx = int.tryParse(value.substring('status:'.length));
          if (idx == null || idx < 0 || idx >= actions.length) return;
          await _applyOrderAction(order, actions[idx]);
          return;
        }
        if (value == 'refund:initiate' && canRefund) {
          await _initiateRefund(order);
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];
        if (actions.isEmpty) {
          items.add(
            const PopupMenuItem<String>(
              enabled: false,
              value: 'status:none',
              child: Text('No status changes allowed'),
            ),
          );
        } else {
          for (var i = 0; i < actions.length; i++) {
            final a = actions[i];
            items.add(
              PopupMenuItem<String>(
                value: 'status:$i',
                child: Text(
                  a.buttonLabel,
                  style: TextStyle(
                    color: a.destructive ? Colors.red.shade800 : null,
                    fontWeight: a.destructive ? FontWeight.w600 : null,
                  ),
                ),
              ),
            );
          }
        }
        items.add(const PopupMenuDivider());
        if (isCod) {
          items.add(
            const PopupMenuItem<String>(
              enabled: false,
              value: 'refund:cod',
              child: Text('No refund required (COD)'),
            ),
          );
        } else {
          items.add(
            PopupMenuItem<String>(
              enabled: canRefund,
              value: 'refund:initiate',
              child: Text(canRefund ? 'Initiate Refund' : refundLabel),
            ),
          );
        }
        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.25)),
        ),
        child: Text(
          (isUpdating || isRefunding) ? 'Updating...' : 'Actions',
          style: TextStyle(
            color: (isUpdating || isRefunding) ? Colors.grey : Colors.blueGrey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  bool _canInitiateRefund(AdminOrderRow o) {
    final pm = o.paymentMethod.toLowerCase().trim();
    final ps = o.paymentStatus.toLowerCase().trim();
    final rs = o.refundStatus.toLowerCase().trim();
    final os = canonicalAdminOrderStatus(o.status);
    return pm == 'razorpay' &&
        ps == 'paid' &&
        rs == 'none' &&
        os != 'cancelled_without_payment';
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
      case 'cancel_rejected':
        color = Colors.deepOrange;
        break;
      default:
        color = Colors.blueGrey;
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Chip(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        label: Text(
          _orderStatusDisplayLabel(c),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: color.withValues(alpha: 0.12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
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
        return 'Cancel pending';
      case 'cancelled':
        return 'Cancelled';
      case 'cancel_rejected':
        return 'Cancel rejected';
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
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }

  Widget _paymentMethodBadge(String raw) {
    final v = raw.toLowerCase().trim();
    final isCod = v == 'cod';
    final color = isCod ? Colors.amber.shade800 : Colors.green.shade700;
    final label = isCod ? 'COD' : 'ONLINE';
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    );
  }

  Widget _deliveryStatusBadge(String? deliveryStatus, String? shipmentStatus) {
    final raw = (deliveryStatus ?? shipmentStatus ?? '').toLowerCase().trim();
    if (raw.isEmpty) return const Text('—');
    final label = switch (raw) {
      'created' => 'Created',
      'shipped' => 'Shipped',
      'in_transit' => 'In Transit',
      'out_for_delivery' => 'Out for Delivery',
      'delivered' => 'Delivered',
      'cancelled' => 'Cancelled',
      'rto_initiated' => 'RTO Initiated',
      'rto_completed' => 'RTO',
      _ => raw.replaceAll('_', ' '),
    };
    final color = switch (raw) {
      'delivered' => Colors.green.shade700,
      'cancelled' => Colors.red.shade700,
      'out_for_delivery' => Colors.teal.shade700,
      'in_transit' => Colors.blue.shade700,
      'shipped' => Colors.indigo.shade700,
      'created' => Colors.blueGrey.shade700,
      'rto_initiated' || 'rto_completed' => Colors.deepOrange.shade700,
      _ => Colors.blueGrey.shade700,
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }

  Widget _deliveryModeBadge(AdminOrderRow o) {
    final mode = (o.deliveryMethod ?? '').toLowerCase().trim();
    final ds = (o.deliveryStatus ?? '').toLowerCase().trim();
    String label;
    Color color;
    if (mode == 'shiprocket_delivery') {
      label = 'Shiprocket';
      color = Colors.blue.shade700;
    } else if (mode == 'manual_delivery') {
      label = 'Manual';
      color = Colors.deepPurple.shade700;
    } else if (mode.isEmpty && ds == 'cancelled') {
      label = 'Reset (SR cancelled)';
      color = Colors.deepOrange.shade800;
    } else {
      label = 'Not set';
      color = Colors.blueGrey.shade700;
    }
    final suffix = (o.shipmentId ?? '').trim().isNotEmpty ? ' • ID set' : '';
    return Chip(
      label: Text('$label$suffix'),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }

  Widget _refundStatusBadge(AdminOrderRow o) {
    final s = o.refundStatus.toLowerCase().trim();
    if (s == 'none' || s.isEmpty) return const Text('—');
    Color color;
    String label;
    switch (s) {
      case 'requested':
        color = Colors.amber.shade800;
        label = 'Requested';
        break;
      case 'processing':
        color = Colors.deepPurple;
        label = 'Processing';
        break;
      case 'refunded':
        color = Colors.green.shade800;
        final amt = o.refundAmountPaise == null ? '' : ' ${formatInrAmount(o.refundAmountPaise! / 100)}';
        label = 'Refunded$amt';
        break;
      case 'rejected':
        color = Colors.red.shade700;
        label = 'Rejected';
        break;
      default:
        color = Colors.blueGrey;
        label = s;
    }
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }

  Future<void> _initiateRefund(AdminOrderRow order) async {
    final confirmed = await _showRefundConfirmDialogForOrder(order);
    if (confirmed != true || !mounted) return;
    final orderId = order.id;
    setState(() => _refundingOrderIds.add(orderId));
    try {
      await ref.read(adminServiceProvider).approveRefundForOrder(orderId: orderId);
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminOrderDetailsProvider(orderId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund initiated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refund failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _refundingOrderIds.remove(orderId));
    }
  }

  Future<bool?> _showRefundConfirmDialogForOrder(AdminOrderRow order) {
    final refundPaise = order.refundAmountPaise ?? (order.totalAmount * 100).round();
    final highValue = refundPaise > 500000;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Confirmation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order ID: ${order.id}'),
              Text('Customer Name: ${order.customerName}'),
              Text('Payment Method: ${order.paymentMethod.toUpperCase()}'),
              Text('Total Paid Amount: ${formatInrAmount(order.totalAmount)}'),
              Text('Refund Amount: ${formatInrAmount(refundPaise / 100)}'),
              const SizedBox(height: 10),
              const Text(
                'This action will send money back to the customer. Refunds cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (highValue) ...[
                const SizedBox(height: 8),
                Text(
                  '\u26A0 High value refund. Please verify before confirming.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyOrderAction(
    AdminOrderRow order,
    AdminOrderNextAction action,
  ) async {
    final noteOutcome = await showAdminOrderStatusConfirmDialog(
      context,
      action: action,
    );
    if (!mounted || noteOutcome == null) return;

    final orderId = order.id;
    setState(() => _updatingOrderIds.add(orderId));
    try {
      await ref.read(adminServiceProvider).updateOrderStatus(
            orderId: orderId,
            status: action.targetStatusTitleCase,
            notes: noteOutcome.isEmpty ? null : noteOutcome,
          );
      await trySendOrderStatusFcmForTarget(
        ref.read(fcmNotificationSenderProvider),
        userId: order.userId,
        orderId: orderId,
        targetStatusTitleCase: action.targetStatusTitleCase,
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
      final rawError = e.toString().toLowerCase();
      final triedShipped = action.targetStatusTitleCase.trim().toLowerCase() == 'shipped';
      final missingShipmentDetails = rawError.contains('order_checklist_missing_tracking') ||
          rawError.contains('order_checklist_missing_courier') ||
          rawError.contains('order_checklist_missing_package_weight') ||
          rawError.contains('order_checklist_missing_package_dimensions') ||
          rawError.contains('tracking') && rawError.contains('missing') ||
          rawError.contains('courier') && rawError.contains('missing') ||
          rawError.contains('null');
      if (triedShipped && missingShipmentDetails) {
        Navigator.of(context).pushNamed(
          '/admin/orders/details/$orderId?focusShipment=1',
        );
        return;
      }
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
