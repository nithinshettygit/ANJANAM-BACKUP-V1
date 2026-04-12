import 'package:ecommerce_app/features/notifications/data/services/fcm_edge_function_notification_sender.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';
import 'package:ecommerce_app/presentation/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../utils/admin_android_ui.dart';
import '../utils/admin_return_status_push.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_state_view.dart';

class AdminReturnsPage extends ConsumerStatefulWidget {
  const AdminReturnsPage({super.key});

  @override
  ConsumerState<AdminReturnsPage> createState() => _AdminReturnsPageState();
}

class _AdminReturnsPageState extends ConsumerState<AdminReturnsPage> {
  String _statusFilter = 'all';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AdminReturnRow? _selectedReturn;

  static const _filters = <String, String>{
    'all': 'All',
    'requested': 'Requested',
    'approved': 'Approved',
    'pickup_scheduled': 'Pickup Scheduled',
    'rejected': 'Rejected',
    'picked_up': 'Picked up',
    'returned': 'Returned',
    'refund_completed': 'Completed',
  };

  String _reasonLabel(String db) {
    switch (db) {
      case 'damaged_item':
        return 'Damaged item';
      case 'wrong_product':
        return 'Wrong product';
      case 'size_issue':
        return 'Size issue';
      case 'not_satisfied':
        return 'Not satisfied';
      default:
        return db;
    }
  }

  String _statusLabel(String db) {
    final s = _norm(db);
    switch (s) {
      case 'pickup_scheduled':
        return 'Pickup Scheduled';
      case 'refund_completed':
        return 'Completed';
      default:
        return _filters[s] ?? db;
    }
  }

  String _norm(String? value) => (value ?? '').trim().toLowerCase();

  String _statusOf(AdminReturnRow r) => _norm(r.returnStatus);

  Future<void> _reload() async {
    ref.invalidate(adminReturnsProvider(_statusFilter));
  }

  Future<void> _approve(AdminReturnRow r) async {
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'approved',
          );
      await trySendReplacementStatusFcm(
        ref.read(fcmNotificationSenderProvider),
        userId: r.userId,
        orderId: r.orderId,
        status: 'approved',
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return approved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reject(AdminReturnRow r) async {
    final ctrl = TextEditingController(text: r.rejectionReason ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject return'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason for customer',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'rejected',
            rejectionReason: ctrl.text.trim(),
          );
      await trySendReplacementStatusFcm(
        ref.read(fcmNotificationSenderProvider),
        userId: r.userId,
        orderId: r.orderId,
        status: 'rejected',
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return rejected.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _markPickedUp(AdminReturnRow r) async {
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'picked_up',
          );
      await trySendReplacementStatusFcm(
        ref.read(fcmNotificationSenderProvider),
        userId: r.userId,
        orderId: r.orderId,
        status: 'picked_up',
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as picked up.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _markReturned(AdminReturnRow r) async {
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'returned',
          );
      await trySendReplacementStatusFcm(
        ref.read(fcmNotificationSenderProvider),
        userId: r.userId,
        orderId: r.orderId,
        status: 'returned',
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as returned.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _processRefund(AdminReturnRow r) async {
    if (!_canInitiateReturnRefund(r)) {
      final cod = _norm(r.paymentMethod) == 'cod';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cod
                ? 'No refund required (COD).'
                : 'Refund can only be initiated for Razorpay returns in returned status.'),
          ),
        );
      }
      return;
    }
    try {
      await ref.read(adminServiceProvider).approveRefundForOrder(orderId: r.orderId);
      await trySendReplacementStatusFcm(
        ref.read(fcmNotificationSenderProvider),
        userId: r.userId,
        orderId: r.orderId,
        status: 'refunded',
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund initiated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _handleAction(AdminReturnRow r, _ReturnAdminAction action) async {
    switch (action) {
      case _ReturnAdminAction.viewOrder:
        Navigator.of(context).pushNamed('/admin/orders/details/${r.orderId}');
        return;
      case _ReturnAdminAction.viewImages:
        _viewImages(r);
        return;
      case _ReturnAdminAction.approve:
        await _approve(r);
        return;
      case _ReturnAdminAction.reject:
        await _reject(r);
        return;
      case _ReturnAdminAction.markPickedUp:
        await _markPickedUp(r);
        return;
      case _ReturnAdminAction.markReturned:
        await _markReturned(r);
        return;
      case _ReturnAdminAction.processRefund:
        await _processRefund(r);
        return;
    }
  }

  List<_ActionMenuItem> _menuItemsFor(AdminReturnRow r) {
    final items = <_ActionMenuItem>[];
    items.add(const _ActionMenuItem(
      action: _ReturnAdminAction.viewOrder,
      label: 'View order',
      icon: Icons.receipt_long_outlined,
    ));
    if (r.returnImages.isNotEmpty) {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.viewImages,
        label: 'View images',
        icon: Icons.photo_library_outlined,
      ));
    }

    final status = _statusOf(r);
    if (status == 'requested') {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.approve,
        label: 'Approve return',
        icon: Icons.check_circle_outline,
      ));
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.reject,
        label: 'Reject return',
        icon: Icons.cancel_outlined,
      ));
    }
    if (status == 'approved') {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.markPickedUp,
        label: 'Mark pickup done',
        icon: Icons.local_shipping_outlined,
      ));
    }
    if (status == 'picked_up') {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.markReturned,
        label: 'Mark returned',
        icon: Icons.inventory_2_outlined,
      ));
    }
    if (status == 'returned') {
      if (_canInitiateReturnRefund(r)) {
        items.add(const _ActionMenuItem(
          action: _ReturnAdminAction.processRefund,
          label: 'Initiate refund',
          icon: Icons.payments_outlined,
        ));
      }
    }
    return items;
  }

  bool _canInitiateReturnRefund(AdminReturnRow r) {
    final paymentMethod = _norm(r.paymentMethod);
    final returnStatus = _norm(r.returnStatus);
    final orderRefundStatus = _norm(r.orderRefundStatus);
    final hasRefund = orderRefundStatus != 'none' || (r.orderRefundAmountPaise ?? 0) > 0;
    final eligibleReturnState =
        returnStatus == 'returned' ||
        returnStatus == 'completed' ||
        returnStatus == 'refund_completed';
    return paymentMethod == 'razorpay' &&
        eligibleReturnState &&
        !hasRefund;
  }

  void _viewImages(AdminReturnRow r) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Return images', style: TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              ...r.returnImages.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppNetworkImage(
                    imageUrl: url,
                    width: 480,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminReturnsProvider(_statusFilter));

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _selectedReturn == null
          ? null
          : Drawer(
              child: SafeArea(
                child: _buildManageDrawer(_selectedReturn!),
              ),
            ),
      body: AdminStateView(
        isLoading: async.isLoading,
        error: async.asError?.error,
        isEmpty: false,
        emptyMessage: 'No returns',
        child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          final compact = kAdminAndroidCompactChrome;
          final denseWeb = !compact;
          final requestedCount = rows.where((r) => _statusOf(r) == 'requested').length;
          final approvedCount = rows.where((r) => _statusOf(r) == 'approved').length;
          final rejectedCount = rows.where((r) => _statusOf(r) == 'rejected').length;
          final completedCount = rows.where((r) => _statusOf(r) == 'refund_completed').length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: compact ? EdgeInsets.zero : null,
                child: Padding(
                  padding: denseWeb
                      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                      : const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: denseWeb ? 8 : 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        isDense: denseWeb,
                        value: _statusFilter,
                        items: _filters.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                      Text(
                        'Total: ${rows.length} | Pending: $requestedCount | Approved: $approvedCount | Rejected: $rejectedCount | Completed: $completedCount',
                        style: TextStyle(
                          fontSize: denseWeb ? 11 : 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AdminDataTable<AdminReturnRow>(
                  rows: rows,
                  emptyMessage: 'No return requests',
                  minTableWidth: 1680,
                  columns: [
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Return ID',
                      sortValue: (r) => r.id,
                      cellBuilder: (r) => SelectableText(r.id),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Order ID',
                      sortValue: (r) => r.orderId,
                      cellBuilder: (r) => SelectableText(r.orderId),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Customer',
                      sortValue: (r) => r.customerName,
                      cellBuilder: (r) => Text(r.customerName),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Product',
                      sortValue: (r) => r.lineTitle,
                      cellBuilder: (r) => Text(
                        r.lineTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Reason',
                      sortValue: (r) => r.returnReason,
                      cellBuilder: (r) => Text(_reasonLabel(r.returnReason)),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Type',
                      sortValue: (r) => r.returnType,
                      cellBuilder: (r) => Text(r.returnType),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Status',
                      sortValue: (r) => r.returnStatus,
                      cellBuilder: (r) => _returnStatusBadge(_statusOf(r)),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Payment Method',
                      sortValue: (r) => r.paymentMethod,
                      cellBuilder: (r) => _paymentMethodBadge(r.paymentMethod),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Refund Status',
                      sortValue: (r) => r.orderRefundStatus,
                      cellBuilder: (r) => _refundStatusBadge(
                        r.orderRefundStatus,
                        amountPaise: r.orderRefundAmountPaise,
                      ),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Created At',
                      sortValue: (r) => r.createdAt.millisecondsSinceEpoch,
                      cellBuilder: (r) => Text(formatOrderDetailsDateTime(r.createdAt)),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Actions',
                      sortValue: (_) => '',
                      cellBuilder: (r) {
                        return OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _selectedReturn = r);
                            _scaffoldKey.currentState?.openEndDrawer();
                          },
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: const Text('Manage'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildManageDrawer(AdminReturnRow r) {
    final actions = _menuItemsFor(r);
    final timeline = _buildReturnTimeline(r);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Manage Return',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText('Return ID: ${r.id}'),
        SelectableText('Order ID: ${r.orderId}'),
        const SizedBox(height: 12),
        const Text('Product details', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(
          r.lineTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text('Amount: ${formatRupee(r.lineAmount)}'),
        const SizedBox(height: 12),
        const Text('Customer info', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(
          r.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SelectableText('User: ${r.userId}'),
        const SizedBox(height: 12),
        const Text('Return reason', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(_reasonLabel(r.returnReason)),
        if ((r.returnNote ?? '').trim().isNotEmpty) Text('Note: ${r.returnNote}'),
        const SizedBox(height: 12),
        const Text('Uploaded images', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (r.returnImages.isEmpty)
          const Text('No images')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final img in r.returnImages)
                GestureDetector(
                  onTap: () => _viewImages(r),
                  child: AppNetworkImage(
                    imageUrl: img,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        const Text('Return timeline', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...timeline.map((t) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timeline, size: 18),
              title: Text(t),
            )),
        const SizedBox(height: 12),
        const Text('Actions', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_norm(r.paymentMethod) == 'cod')
          const Text(
            'No refund required (COD)',
            style: TextStyle(color: Colors.black54),
          ),
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FilledButton.tonalIcon(
              onPressed: () => _handleAction(r, a.action),
              icon: Icon(a.icon, size: 18),
              label: Text(a.label),
            ),
          ),
      ],
    );
  }

  List<String> _buildReturnTimeline(AdminReturnRow r) {
    final out = <String>['Return Requested'];
    final s = _statusOf(r);
    if (s == 'approved' || s == 'picked_up' || s == 'returned' || s == 'refund_completed') {
      out.add('Approved');
    }
    if (s == 'pickup_scheduled') out.add('Pickup Scheduled');
    if (s == 'picked_up' || s == 'returned' || s == 'refund_completed') {
      out.add('Pickup Completed');
    }
    if (s == 'returned' || s == 'refund_completed') {
      out.add('Product Received');
      out.add('Refund Initiated');
    }
    if (_norm(r.orderRefundStatus) == 'refunded' || s == 'refund_completed') {
      out.add('Refund Completed');
    }
    if (s == 'rejected') out.add('Rejected');
    return out;
  }

  Widget _returnStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'requested':
        color = Colors.amber.shade800;
        break;
      case 'approved':
        color = Colors.blue.shade700;
        break;
      case 'pickup_scheduled':
        color = Colors.purple.shade600;
        break;
      case 'returned':
      case 'refund_completed':
        color = Colors.green.shade700;
        break;
      case 'rejected':
        color = Colors.red.shade700;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(_statusLabel(status)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }

  Widget _paymentMethodBadge(String raw) {
    final v = _norm(raw);
    final isCod = v == 'cod';
    final color = isCod ? Colors.amber.shade800 : Colors.green.shade700;
    return Chip(
      label: Text(isCod ? 'COD' : 'ONLINE'),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    );
  }

  Widget _refundStatusBadge(String raw, {int? amountPaise}) {
    final s = _norm(raw);
    if (s == 'none' || s.isEmpty) return const Text('—');
    Color color;
    String label;
    switch (s) {
      case 'requested':
      case 'pending':
        color = Colors.amber.shade800;
        label = 'Pending';
        break;
      case 'processing':
        color = Colors.purple.shade700;
        label = 'Processing';
        break;
      case 'refunded':
        color = Colors.green.shade900;
        final amt = amountPaise == null ? '' : ' ${formatRupee(amountPaise / 100)}';
        label = 'Refunded$amt';
        break;
      case 'rejected':
        color = Colors.red.shade700;
        label = 'Rejected';
        break;
      default:
        color = Colors.blueGrey;
        label = raw;
    }
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.35)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

enum _ReturnAdminAction {
  viewOrder,
  viewImages,
  approve,
  reject,
  markPickedUp,
  markReturned,
  processRefund,
}

class _ActionMenuItem {
  final _ReturnAdminAction action;
  final String label;
  final IconData icon;

  const _ActionMenuItem({
    required this.action,
    required this.label,
    required this.icon,
  });
}
