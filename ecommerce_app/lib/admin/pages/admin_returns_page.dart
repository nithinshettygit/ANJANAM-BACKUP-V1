import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';
import 'package:ecommerce_app/presentation/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
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
    'return_requested': 'Return requested',
    'return_approved': 'Return approved',
    'pickup_scheduled': 'Pickup scheduled',
    'item_picked_up': 'Item picked up',
    'item_received_warehouse': 'At warehouse',
    'inspection_passed': 'Inspection passed',
    'inspection_failed': 'Inspection failed',
    'replacement_in_progress': 'Replacement in progress',
    'return_rejected': 'Rejected',
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

  bool _isReplacement(AdminReturnRow r) => _norm(r.returnType) == 'replacement';

  String _statusOf(AdminReturnRow r) => _norm(r.returnStatus);

  Future<void> _reload() async {
    ref.invalidate(adminReturnsProvider(_statusFilter));
  }

  Future<void> _approve(AdminReturnRow r) async {
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'return_approved',
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
            newStatus: 'return_rejected',
            rejectionReason: ctrl.text.trim(),
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

  Future<void> _schedulePickup(AdminReturnRow r) async {
    final notesCtrl = TextEditingController(text: r.pickupNotes ?? '');
    final courierCtrl = TextEditingController(text: r.pickupCourierPartner ?? '');
    var pickedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Schedule pickup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pickup date'),
                  subtitle: Text(pickedDate.toLocal().toString().split(' ').first),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: pickedDate,
                      );
                      if (d != null) setLocal(() => pickedDate = d);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: courierCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Courier partner',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions for customer (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (courierCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Courier partner is required.')),
      );
      notesCtrl.dispose();
      courierCtrl.dispose();
      return;
    }
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'pickup_scheduled',
            pickupScheduledAt: pickedDate,
            pickupCourierPartner: courierCtrl.text.trim(),
            pickupNotes: notesCtrl.text.trim(),
          );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup scheduled.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      notesCtrl.dispose();
      courierCtrl.dispose();
    }
  }

  Future<void> _markPickedUp(AdminReturnRow r) async {
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'item_picked_up',
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

  Future<void> _markWarehouse(AdminReturnRow r) async {
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'item_received_warehouse',
            warehouseReceiptAt: DateTime.now(),
          );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as received at warehouse.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _passInspection(AdminReturnRow r) async {
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'inspection_passed',
          );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection marked as passed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _failInspection(AdminReturnRow r) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inspection failed'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A reason is required.')),
      );
      ctrl.dispose();
      return;
    }
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: r.id,
            newStatus: 'inspection_failed',
            rejectionReason: ctrl.text.trim(),
          );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection marked as failed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _processRefund(AdminReturnRow r) async {
    final amountCtrl = TextEditingController(text: r.lineAmount.toStringAsFixed(2));
    String method = 'original_payment';
    final txCtrl = TextEditingController(text: r.orderPaymentTransactionId ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Process refund'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Refund amount (INR)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(
                    labelText: 'Refund method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'original_payment', child: Text('Original payment')),
                    DropdownMenuItem(value: 'wallet_credit', child: Text('Wallet credit')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? method),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: txCtrl,
                  decoration: InputDecoration(
                    labelText: method == 'original_payment'
                        ? 'Payment / reference ID (required for original payment)'
                        : 'Payment / reference ID (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create refund')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final amt = double.tryParse(amountCtrl.text.trim());
    if (amt == null || amt < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      amountCtrl.dispose();
      txCtrl.dispose();
      return;
    }
    if (method == 'original_payment' && txCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter payment reference id for original payment refund.')),
      );
      amountCtrl.dispose();
      txCtrl.dispose();
      return;
    }
    try {
      await ref.read(adminServiceProvider).createRefundForReturn(
            returnId: r.id,
            amount: amt,
            refundMethod: method,
            paymentTransactionId: txCtrl.text.trim().isEmpty ? null : txCtrl.text.trim(),
          );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund record created (initiated).')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is RepositoryException ? e.message : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      amountCtrl.dispose();
      txCtrl.dispose();
    }
  }

  Future<void> _advanceRefund(AdminReturnRow r) async {
    final id = r.refundId;
    if (id == null) return;
    final next = r.refundStatus == 'refund_initiated'
        ? 'refund_processed'
        : r.refundStatus == 'refund_processed'
            ? 'refund_completed'
            : null;
    if (next == null) return;
    final method = _norm(r.refundMethod ?? '');
    String? rzpId;
    String? gatewayStatus;
    if (next == 'refund_processed' && method == 'original_payment') {
      final c = TextEditingController(text: r.razorpayRefundId ?? '');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Razorpay refund id'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Refund id from Razorpay',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      );
      if (ok != true || !mounted) {
        c.dispose();
        return;
      }
      rzpId = c.text.trim();
      c.dispose();
      if (rzpId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Razorpay refund id is required.')),
        );
        return;
      }
    }
    if (next == 'refund_completed' && method == 'original_payment') {
      var sel = _norm(r.gatewayRefundStatus ?? '');
      if (sel != 'processed' && sel != 'completed') sel = 'processed';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Gateway refund status'),
            content: DropdownButtonFormField<String>(
              value: sel,
              decoration: const InputDecoration(
                labelText: 'Verified status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'processed', child: Text('processed')),
                DropdownMenuItem(value: 'completed', child: Text('completed')),
              ],
              onChanged: (v) => setLocal(() => sel = v ?? 'processed'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
            ],
          ),
        ),
      );
      if (ok != true || !mounted) return;
      gatewayStatus = sel;
    }
    try {
      await ref.read(adminServiceProvider).updateRefundStatus(
            refundId: id,
            newStatus: next,
            razorpayRefundId: rzpId,
            gatewayRefundStatus: gatewayStatus,
          );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refund → $next')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

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
      case _ReturnAdminAction.schedulePickup:
        await _schedulePickup(r);
        return;
      case _ReturnAdminAction.markPickedUp:
        await _markPickedUp(r);
        return;
      case _ReturnAdminAction.markReceived:
        await _markWarehouse(r);
        return;
      case _ReturnAdminAction.passInspection:
        await _passInspection(r);
        return;
      case _ReturnAdminAction.failInspection:
        await _failInspection(r);
        return;
      case _ReturnAdminAction.processRefund:
        await _processRefund(r);
        return;
      case _ReturnAdminAction.markRefundProcessed:
      case _ReturnAdminAction.markRefundCompleted:
        await _advanceRefund(r);
        return;
      case _ReturnAdminAction.openReplacementOrder:
        if (!mounted || r.replacementOrderId == null || r.replacementOrderId!.isEmpty) {
          return;
        }
        Navigator.of(context).pushNamed(
          '/admin/orders/details',
          arguments: r.replacementOrderId,
        );
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
    if (status == 'return_requested') {
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
    if (status == 'return_approved') {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.schedulePickup,
        label: 'Schedule pickup',
        icon: Icons.local_shipping_outlined,
      ));
    }
    if (status == 'replacement_in_progress' &&
        r.replacementOrderId != null &&
        r.replacementOrderId!.isNotEmpty) {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.openReplacementOrder,
        label: 'Open replacement order',
        icon: Icons.receipt_long_outlined,
      ));
    }
    if (status == 'pickup_scheduled') {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.markPickedUp,
        label: 'Mark item picked up',
        icon: Icons.local_shipping_outlined,
      ));
    }
    if (status == 'item_picked_up') {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.markReceived,
        label: 'Mark received at warehouse',
        icon: Icons.inventory_2_outlined,
      ));
    }
    if (status == 'item_received_warehouse') {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.passInspection,
        label: 'Pass inspection',
        icon: Icons.fact_check_outlined,
      ));
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.failInspection,
        label: 'Fail inspection',
        icon: Icons.error_outline,
      ));
    }
    if (!_isReplacement(r) &&
        r.refundId == null &&
        (status == 'item_received_warehouse' || status == 'inspection_passed')) {
      items.add(const _ActionMenuItem(
        action: _ReturnAdminAction.processRefund,
        label: 'Process refund',
        icon: Icons.payments_outlined,
      ));
    }
    if (r.refundId != null && r.refundStatus != null && r.refundStatus != 'refund_completed') {
      final pendingProcessed = _norm(r.refundStatus) == 'refund_initiated';
      items.add(
        _ActionMenuItem(
          action: pendingProcessed
              ? _ReturnAdminAction.markRefundProcessed
              : _ReturnAdminAction.markRefundCompleted,
          label: pendingProcessed ? 'Mark refund processed' : 'Mark refund completed',
          icon: pendingProcessed ? Icons.timelapse_outlined : Icons.task_alt_outlined,
        ),
      );
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
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
                      const Text(
                        'Tip: use Manage in each row for lifecycle actions.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
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
                      cellBuilder: (r) => Text(
                        r.refundStatus == null
                            ? '—'
                            : '${r.refundStatus} (${formatRupee(r.refundAmount ?? 0)})',
                      ),
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
  schedulePickup,
  markPickedUp,
  markReceived,
  passInspection,
  failInspection,
  processRefund,
  markRefundProcessed,
  markRefundCompleted,
  openReplacementOrder,
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
