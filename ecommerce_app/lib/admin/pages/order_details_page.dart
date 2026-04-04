import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/formatting/estimated_delivery_format.dart';
import 'package:ecommerce_app/core/invoice/invoice_generator.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_shipping_info.dart';
import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart'
    show formatOrderDetailsDateTime, formatOrderIdDisplay;

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../utils/admin_order_status_workflow.dart';
import '../../features/notifications/data/services/fcm_edge_function_notification_sender.dart';
import '../widgets/admin_cached_image.dart';
import '../widgets/admin_guard.dart';
import '../widgets/admin_state_view.dart';

class AdminOrderDetailsPage extends ConsumerStatefulWidget {
  final String orderId;

  const AdminOrderDetailsPage({super.key, required this.orderId});

  @override
  ConsumerState<AdminOrderDetailsPage> createState() => _AdminOrderDetailsPageState();
}

class _AdminOrderDetailsPageState extends ConsumerState<AdminOrderDetailsPage> {
  final _trackCtrl = TextEditingController();
  final _courierCtrl = TextEditingController();
  final _pkgWeightCtrl = TextEditingController();
  final _pkgDimCtrl = TextEditingController();
  DateTime? _estDelivery;
  bool _shipmentDirty = false;
  String? _syncedShipmentOrderId;
  bool _statusBusy = false;
  bool _shipmentSaving = false;

  @override
  void dispose() {
    _trackCtrl.dispose();
    _courierCtrl.dispose();
    _pkgWeightCtrl.dispose();
    _pkgDimCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AdminOrderDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      _syncedShipmentOrderId = null;
      _shipmentDirty = false;
    }
  }

  bool _shipmentEditableForStatus(String rawStatus) {
    final c = canonicalAdminOrderStatus(rawStatus);
    return c != 'delivered' && c != 'cancelled' && c != 'cancel_requested';
  }

  bool _shipmentFormDiffersFrom(AdminOrderDetails details) {
    final t = _trackCtrl.text.trim();
    final c = _courierCtrl.text.trim();
    final w = _pkgWeightCtrl.text.trim();
    final d = _pkgDimCtrl.text.trim();
    final serverT = (details.trackingNumber ?? '').trim();
    final serverC = (details.courierName ?? '').trim();
    final serverW = details.packageWeightKg == null
        ? ''
        : details.packageWeightKg!.toString();
    final serverD = (details.packageDimensionsCm ?? '').trim();
    if (t != serverT || c != serverC || w != serverW || d != serverD) return true;
    final pick = _estDelivery;
    final srv = details.estimatedDeliveryDate;
    if (pick == null && srv == null) return false;
    if (pick == null || srv == null) return true;
    return pick.year != srv.year || pick.month != srv.month || pick.day != srv.day;
  }

  void _syncShipmentFieldsFromDetails(AdminOrderDetails details, String orderId) {
    if (_shipmentDirty) return;
    if (_syncedShipmentOrderId == orderId) return;
    _trackCtrl.text = details.trackingNumber ?? '';
    _courierCtrl.text = details.courierName ?? '';
    _pkgWeightCtrl.text = details.packageWeightKg == null
        ? ''
        : details.packageWeightKg!.toString();
    _pkgDimCtrl.text = details.packageDimensionsCm ?? '';
    setState(() {
      _estDelivery = details.estimatedDeliveryDate;
      _syncedShipmentOrderId = orderId;
    });
  }

  String _statusDisplayLabel(String raw) {
    final c = canonicalAdminOrderStatus(raw);
    switch (c) {
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
        return raw;
    }
  }

  Future<void> _runStatusAction(
    BuildContext context,
    String orderId,
    String userId,
    AdminOrderNextAction action,
  ) async {
    final noteOutcome = await showAdminOrderStatusConfirmDialog(
      context,
      action: action,
    );
    if (!context.mounted || noteOutcome == null) return;

    setState(() => _statusBusy = true);
    try {
      await ref.read(adminServiceProvider).updateOrderStatus(
            orderId: orderId,
            status: action.targetStatusTitleCase,
            notes: noteOutcome.isEmpty ? null : noteOutcome,
          );

      // Best-effort push for customer order updates.
      final target = action.targetStatusTitleCase.toLowerCase().trim();
      if (target == 'processing' || target == 'shipped' || target == 'delivered') {
        final (title, message) = switch (target) {
          'processing' => (
              'Order confirmed',
              'We are preparing your order.',
            ),
          'shipped' => (
              'Order shipped',
              'Your order is on the way.',
            ),
          _ => (
              'Order delivered',
              'Your order has been delivered. Thank you for shopping with us!',
            ),
        };

        await ref.read(fcmNotificationSenderProvider).sendOrderStatusPush(
              userId: userId,
              orderId: orderId,
              title: title,
              message: message,
              kind: 'order_status',
              redirectType: 'order',
              redirectValue: orderId,
            );
      }

      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(adminOrderActionSuccessMessage(action))),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _runApproveCancellation(BuildContext context, String orderId, String userId) async {
    final noteOutcome = await showAdminOrderStatusConfirmDialog(
      context,
      action: const AdminOrderNextAction(
        buttonLabel: 'Approve cancellation',
        targetStatusTitleCase: 'Cancelled',
        confirmationTitle: 'Approve cancellation',
        confirmationBody:
            'The order will be cancelled, inventory will be restored, and a refund row will be created automatically for paid Razorpay orders.',
        destructive: true,
      ),
    );
    if (!context.mounted || noteOutcome == null) return;

    setState(() => _statusBusy = true);
    try {
      await ref.read(adminServiceProvider).approveOrderCancellation(
            orderId: orderId,
            notes: noteOutcome.isEmpty ? null : noteOutcome,
          );
      await ref.read(fcmNotificationSenderProvider).sendOrderStatusPush(
            userId: userId,
            orderId: orderId,
            title: 'Order cancelled',
            message: 'Your cancellation was approved. If you paid online, a refund has been initiated.',
            kind: 'order_status',
            redirectType: 'order',
            redirectValue: orderId,
          );
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation approved. Order is cancelled.')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _runRejectCancellation(BuildContext context, String orderId, String userId) async {
    final noteOutcome = await showAdminOrderStatusConfirmDialog(
      context,
      action: const AdminOrderNextAction(
        buttonLabel: 'Reject cancellation',
        targetStatusTitleCase: 'Processing',
        confirmationTitle: 'Reject cancellation',
        confirmationBody:
            'The order will return to its previous fulfilment status and the customer will be notified.',
      ),
    );
    if (!context.mounted || noteOutcome == null) return;

    setState(() => _statusBusy = true);
    try {
      await ref.read(adminServiceProvider).rejectOrderCancellation(
            orderId: orderId,
            notes: noteOutcome.isEmpty ? null : noteOutcome,
          );
      await ref.read(fcmNotificationSenderProvider).sendOrderStatusPush(
            userId: userId,
            orderId: orderId,
            title: 'Cancellation request declined',
            message: 'Your order will continue processing. Open the order for details.',
            kind: 'order_status',
            redirectType: 'order',
            redirectValue: orderId,
          );
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      ref.invalidate(adminOrdersProvider);
      ref.invalidate(adminDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation request rejected.')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Order _orderEntityForInvoice(AdminOrderDetails d) {
    final o = d.order;
    final items = d.items
        .map(
          (i) => OrderItem(
            productId: i.productId,
            title: i.title,
            imageUrls: i.imageUrls,
            unitPrice: i.unitPrice,
            currency: i.currency,
            quantity: i.quantity,
          ),
        )
        .toList();
    return Order(
      id: o.id,
      userId: o.userId,
      status: OrderStatusX.fromDbValue(o.status),
      items: items,
      currency: o.currency,
      createdAt: o.createdAt,
      deliveryFee: o.deliveryFee,
      trackingNumber: d.trackingNumber,
      courierName: d.courierName,
      estimatedDeliveryDate: d.estimatedDeliveryDate,
      paymentMethod: orderPaymentMethodFromDb(d.paymentMethod),
      paymentStatus: orderPaymentStatusFromDb(d.paymentStatus),
      razorpayPaymentId: d.razorpayPaymentId ?? o.razorpayPaymentId,
      returnDeadline: null,
    );
  }

  OrderShippingInfo _shippingForInvoice(AdminOrderDetails d) {
    final structured = _hasStructuredShipping(d);
    final String? addressLine;
    if (structured) {
      addressLine = d.shippingAddressLine != null && d.shippingAddressLine!.trim().isNotEmpty
          ? d.shippingAddressLine!.trim()
          : null;
    } else {
      final line = d.shippingAddress.trim();
      addressLine = line.isEmpty ? null : line;
    }
    final name = d.shippingFullName != null && d.shippingFullName!.trim().isNotEmpty
        ? d.shippingFullName!.trim()
        : (d.order.customerName.trim().isEmpty ? null : d.order.customerName.trim());
    return OrderShippingInfo(
      fullName: name,
      phone: d.shippingPhone,
      addressLine: addressLine,
      city: d.shippingCity,
      postalCode: d.shippingPostalCode,
    );
  }

  Future<void> _onDownloadAdminInvoice(
    BuildContext context,
    AdminOrderDetails details,
  ) async {
    if (details.items.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice cannot be generated.')),
      );
      return;
    }
    try {
      final order = _orderEntityForInvoice(details);
      final gen = InvoiceGenerator();
      final bytes = await gen.generateInvoicePdf(
        order,
        order.items,
        shipping: _shippingForInvoice(details),
      );
      if (!context.mounted) return;
      await previewInvoicePdf(
        bytes,
        name: 'invoice_${formatOrderIdDisplay(order.id)}',
      );
    } catch (e, st) {
      debugPrint('Admin invoice: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice cannot be generated.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderId;

    ref.listen(adminOrderDetailsProvider(orderId), (_, next) {
      next.whenData((details) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncShipmentFieldsFromDetails(details, details.order.id);
        });
      });
    });
    final detailsAsync = ref.watch(adminOrderDetailsProvider(orderId));

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/orders'),
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AdminStateView(
            isLoading: detailsAsync.isLoading,
            error: detailsAsync.asError?.error,
            isEmpty: false,
            emptyMessage: 'No order details available',
            child: detailsAsync.when(
              data: (details) {
                    final order = details.order;
                    final shipmentEditable = _shipmentEditableForStatus(order.status);
                    final actions = adminOrderNextActions(order.status);
                    return ListView(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Customer name: ${order.customerName}'),
                                Text('Customer email: ${order.customerEmail}'),
                                const SizedBox(height: 8),
                                Text('Order ID: ${order.id}'),
                                Text('Date: ${order.createdAt.toLocal()}'),
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
                                  'Payment Details',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 12),
                                _AdminPaymentDetailLine(
                                  label: 'Payment Method',
                                  value: details.paymentMethod,
                                ),
                                _AdminPaymentDetailLine(
                                  label: 'Payment Status',
                                  value: _adminPaymentStatusLabel(details.paymentStatus),
                                ),
                                _AdminPaymentDetailLine(
                                  label: 'Razorpay Payment ID',
                                  value: _dashIfEmpty(details.razorpayPaymentId),
                                ),
                                _AdminPaymentDetailLine(
                                  label: 'Razorpay Order ID',
                                  value: _dashIfEmpty(details.razorpayOrderId),
                                ),
                                _AdminPaymentDetailLine(
                                  label: 'Order Amount',
                                  value: formatInrAmount(order.totalAmount),
                                ),
                                _AdminPaymentDetailLine(
                                  label: 'Created At',
                                  value: formatOrderDetailsDateTime(order.createdAt.toLocal()),
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
                                  'Shipping address',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                if (_hasStructuredShipping(details)) ...[
                                  if (details.shippingFullName != null &&
                                      details.shippingFullName!.isNotEmpty)
                                    Text(details.shippingFullName!),
                                  if (details.shippingPhone != null &&
                                      details.shippingPhone!.isNotEmpty)
                                    Text('Phone: ${details.shippingPhone}'),
                                  if (details.shippingAddressLine != null &&
                                      details.shippingAddressLine!.isNotEmpty)
                                    Text(details.shippingAddressLine!),
                                  Builder(
                                    builder: (_) {
                                      final cityLine = [
                                        if (details.shippingCity != null &&
                                            details.shippingCity!.isNotEmpty)
                                          details.shippingCity!,
                                        if (details.shippingPostalCode != null &&
                                            details.shippingPostalCode!.isNotEmpty)
                                          details.shippingPostalCode!,
                                      ].join(', ');
                                      if (cityLine.isEmpty) return const SizedBox.shrink();
                                      return Text(cityLine);
                                    },
                                  ),
                                ] else
                                  Text(
                                    details.shippingAddress,
                                    style: Theme.of(context).textTheme.bodyLarge,
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
                                  'Order Actions',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Current status: ${_statusDisplayLabel(order.status)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                if (_statusBusy)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: LinearProgressIndicator(minHeight: 3),
                                  ),
                                if (actions.isEmpty)
                                  Text(
                                    canonicalAdminOrderStatus(order.status) == 'delivered'
                                        ? 'Delivered — no further status changes are allowed.'
                                        : canonicalAdminOrderStatus(order.status) == 'cancelled'
                                            ? 'This order is cancelled. No status updates are available.'
                                            : canonicalAdminOrderStatus(order.status) ==
                                                    'cancel_requested'
                                                ? 'Customer requested cancellation — use Cancellation review below.'
                                                : 'No status changes are available for this order.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  )
                                else
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final a in actions)
                                        FilledButton.tonal(
                                          onPressed: _statusBusy
                                              ? null
                                              : () =>
                                                  _runStatusAction(context, order.id, order.userId, a),
                                          style: a.destructive
                                              ? FilledButton.styleFrom(
                                                  foregroundColor: Theme.of(context).colorScheme.error,
                                                )
                                              : null,
                                          child: Text(a.buttonLabel),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (canonicalAdminOrderStatus(order.status) == 'cancel_requested') ...[
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cancellation review',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Approve to cancel the order (inventory restored; paid Razorpay orders get an automatic refund record). '
                                    'Reject to resume fulfilment at the previous status.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      FilledButton(
                                        onPressed: _statusBusy
                                            ? null
                                            : () => _runApproveCancellation(
                                                  context,
                                                  order.id,
                                                  order.userId,
                                                ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                          foregroundColor: Theme.of(context).colorScheme.onError,
                                        ),
                                        child: const Text('Approve cancellation'),
                                      ),
                                      OutlinedButton(
                                        onPressed: _statusBusy
                                            ? null
                                            : () => _runRejectCancellation(
                                                  context,
                                                  order.id,
                                                  order.userId,
                                                ),
                                        child: const Text('Reject cancellation'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Order Timeline',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ...details.timeline.map((event) {
                                  final sub = StringBuffer(
                                    event.timestamp.toLocal().toString().split('.').first,
                                  );
                                  if (event.notes != null && event.notes!.isNotEmpty) {
                                    sub.writeln();
                                    sub.write(event.notes);
                                  }
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.timeline, size: 18),
                                    title: Text(event.label),
                                    subtitle: Text(sub.toString()),
                                  );
                                }),
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
                                  'Shipment (customer-visible)',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                if (!shipmentEditable) ...[
                                  Text(
                                    canonicalAdminOrderStatus(order.status) == 'cancelled'
                                        ? 'Shipment details cannot be edited for a cancelled order.'
                                        : canonicalAdminOrderStatus(order.status) == 'cancel_requested'
                                            ? 'Shipment is read-only while a cancellation request is open.'
                                            : 'This order is delivered. Tracking and estimated delivery are read-only.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  _AdminShipmentReadOnlyLine(
                                    label: 'Tracking number',
                                    value: details.trackingNumber,
                                  ),
                                  _AdminShipmentReadOnlyLine(
                                    label: 'Courier name',
                                    value: details.courierName,
                                  ),
                                  _AdminShipmentReadOnlyLine(
                                    label: 'Estimated delivery date',
                                    value: details.estimatedDeliveryDate == null
                                        ? null
                                        : formatEstimatedDeliveryDate(details.estimatedDeliveryDate!),
                                  ),
                                  _AdminShipmentReadOnlyLine(
                                    label: 'Package weight (kg)',
                                    value: details.packageWeightKg == null
                                        ? null
                                        : details.packageWeightKg!.toString(),
                                  ),
                                  _AdminShipmentReadOnlyLine(
                                    label: 'Package dimensions (cm)',
                                    value: details.packageDimensionsCm,
                                  ),
                                ] else ...[
                                  TextField(
                                    controller: _trackCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Tracking number',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() => _shipmentDirty = true),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _courierCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Courier name',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() => _shipmentDirty = true                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _pkgWeightCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Package weight (kg)',
                                      border: OutlineInputBorder(),
                                      hintText: 'Required before marking shipped',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setState(() => _shipmentDirty = true),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _pkgDimCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Package dimensions (cm)',
                                      border: OutlineInputBorder(),
                                      hintText: 'e.g. 30×20×10',
                                    ),
                                    onChanged: (_) => setState(() => _shipmentDirty = true),
                                  ),
                                  const SizedBox(height: 10),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Estimated delivery date'),
                                    subtitle: Text(
                                      _estDelivery == null
                                          ? 'Not set'
                                          : formatEstimatedDeliveryDate(_estDelivery!),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_estDelivery != null)
                                          IconButton(
                                            tooltip: 'Clear date',
                                            icon: const Icon(Icons.clear),
                                            onPressed: () => setState(() {
                                              _estDelivery = null;
                                              _shipmentDirty = true;
                                            }),
                                          ),
                                        IconButton(
                                          tooltip: 'Pick date',
                                          icon: const Icon(Icons.calendar_today_outlined),
                                          onPressed: () async {
                                            final initial = _estDelivery == null
                                                ? DateTime.now()
                                                : DateTime(
                                                    _estDelivery!.year,
                                                    _estDelivery!.month,
                                                    _estDelivery!.day,
                                                  );
                                            final picked = await showDatePicker(
                                              context: context,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime.now()
                                                  .add(const Duration(days: 365 * 2)),
                                              initialDate: initial,
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                _estDelivery = picked;
                                                _shipmentDirty = true;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_shipmentSaving)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: LinearProgressIndicator(minHeight: 3),
                                    ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton(
                                      onPressed: (_shipmentSaving ||
                                              _syncedShipmentOrderId != order.id ||
                                              !_shipmentFormDiffersFrom(details))
                                          ? null
                                          : () async {
                                              setState(() => _shipmentSaving = true);
                                              try {
                                                await ref
                                                    .read(adminServiceProvider)
                                                    .updateOrderShipmentInfo(
                                                      orderId: order.id,
                                                      trackingNumber: _trackCtrl.text,
                                                      courierName: _courierCtrl.text,
                                                      estimatedDeliveryDate: _estDelivery,
                                                      packageWeightKg: double.tryParse(
                                                        _pkgWeightCtrl.text.trim(),
                                                      ),
                                                      packageDimensionsCm: _pkgDimCtrl.text.trim(),
                                                    );
                                                if (!context.mounted) return;
                                                setState(() {
                                                  _shipmentDirty = false;
                                                  _syncedShipmentOrderId = null;
                                                });
                                                ref.invalidate(adminOrderDetailsProvider(orderId));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                      content: Text('Shipment details saved')),
                                                );
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Save failed: $e')),
                                                  );
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(() => _shipmentSaving = false);
                                                }
                                              }
                                            },
                                      child: const Text('Save shipment'),
                                    ),
                                  ),
                                ],
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
                                  'Order Items',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ...details.items.map((item) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: item.imageUrls.isNotEmpty
                                        ? AdminCachedImage(
                                            imageUrl: item.imageUrls.first,
                                            width: 44,
                                            height: 44,
                                            borderRadius: BorderRadius.circular(8),
                                          )
                                        : const Icon(Icons.image_not_supported_outlined),
                                    title: Text(item.title),
                                    subtitle: Text('Quantity: ${item.quantity}'),
                                    trailing: Text(
                                      formatInrAmount(item.unitPrice * item.quantity),
                                    ),
                                  );
                                }),
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
                                  'Order summary',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                _summaryRow('Items subtotal', formatInrAmount(order.itemsSubtotal)),
                                _summaryRow(
                                  'Delivery',
                                  order.deliveryFee <= 0
                                      ? 'FREE'
                                      : formatInrAmount(order.deliveryFee),
                                ),
                                const Divider(height: 20),
                                _summaryRow(
                                  'Total payable',
                                  formatInrAmount(order.totalAmount),
                                  emphasize: true,
                                ),
                                if (details.items.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _onDownloadAdminInvoice(context, details),
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                                      label: const Text('Download Invoice'),
                                    ),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }

  static bool _hasStructuredShipping(AdminOrderDetails d) {
    return (d.shippingFullName != null && d.shippingFullName!.isNotEmpty) ||
        (d.shippingPhone != null && d.shippingPhone!.isNotEmpty) ||
        (d.shippingAddressLine != null && d.shippingAddressLine!.isNotEmpty) ||
        (d.shippingCity != null && d.shippingCity!.isNotEmpty) ||
        (d.shippingPostalCode != null && d.shippingPostalCode!.isNotEmpty);
  }

  static Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              fontSize: emphasize ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

String _adminPaymentStatusLabel(String raw) {
  switch (raw.toLowerCase().trim()) {
    case 'paid':
      return 'Paid';
    case 'failed':
      return 'Failed';
    default:
      return 'Pending';
  }
}

String _dashIfEmpty(String? v) {
  final t = v?.trim() ?? '';
  return t.isEmpty ? '—' : t;
}

class _AdminShipmentReadOnlyLine extends StatelessWidget {
  final String label;
  final String? value;

  const _AdminShipmentReadOnlyLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = (value == null || value!.trim().isEmpty) ? '—' : value!.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            display,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _AdminPaymentDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _AdminPaymentDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
