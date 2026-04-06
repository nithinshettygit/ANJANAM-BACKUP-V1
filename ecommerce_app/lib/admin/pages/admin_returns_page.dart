import 'package:ecommerce_app/core/theme/app_colors.dart';
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

  static const _filters = <String, String>{
    'all': 'All',
    'requested': 'Requested',
    'approved': 'Approved',
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
    return _filters[db] ?? db;
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
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'refund_completed',
          );
      await trySendReplacementStatusFcm(
        ref.read(fcmNotificationSenderProvider),
        userId: r.userId,
        orderId: r.orderId,
        status: 'refund_completed',
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund completed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _markRefundCompleted(AdminReturnRow r) async => _processRefund(r);

  Future<void> _handleAction(AdminReturnRow r, _ReturnAdminAction action) async {
    switch (action) {
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
      case _ReturnAdminAction.markRefundCompleted:
        await _markRefundCompleted(r);
        return;
    }
  }

  List<_ActionMenuItem> _menuItemsFor(AdminReturnRow r) {
    final items = <_ActionMenuItem>[];
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
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.processRefund,
        label: 'Mark refund completed',
        icon: Icons.payments_outlined,
      ));
    }
    return items;
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

    return AdminStateView(
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
                      label: 'Item',
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
                      cellBuilder: (r) => Text(_statusLabel(r.returnStatus)),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Created',
                      sortValue: (r) => r.createdAt.millisecondsSinceEpoch,
                      cellBuilder: (r) => Text(formatOrderDetailsDateTime(r.createdAt)),
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Refund',
                      sortValue: (r) => r.refundStatus ?? '',
                      cellBuilder: (r) {
                        if (r.refundStatus == null) return const Text('—');
                        return Text.rich(
                          TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(text: '${r.refundStatus} ('),
                              TextSpan(
                                text: formatRupee(r.refundAmount ?? 0),
                                style: const TextStyle(
                                  color: AppColors.priceText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: ')'),
                            ],
                          ),
                        );
                      },
                    ),
                    AdminTableColumn<AdminReturnRow>(
                      label: 'Actions',
                      sortValue: (_) => '',
                      cellBuilder: (r) {
                        final items = _menuItemsFor(r);
                        if (items.isEmpty) {
                          return const Text('No actions');
                        }
                        return PopupMenuButton<_ReturnAdminAction>(
                          tooltip: 'Manage return',
                          onSelected: (a) => _handleAction(r, a),
                          itemBuilder: (_) => [
                            for (final item in items)
                              PopupMenuItem<_ReturnAdminAction>(
                                value: item.action,
                                child: Row(
                                  children: [
                                    Icon(item.icon, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(item.label)),
                                  ],
                                ),
                              ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.settings_outlined, size: 18),
                                SizedBox(width: 6),
                                Text('Manage'),
                              ],
                            ),
                          ),
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
    );
  }
}

enum _ReturnAdminAction {
  viewImages,
  approve,
  reject,
  markPickedUp,
  markReturned,
  processRefund,
  markRefundCompleted,
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
