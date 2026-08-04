import 'dart:async';

import 'package:ecommerce_app/core/invoice/invoice_generator.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/core/payments/razorpay_service.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/features/checkout/state/order_payment_provider.dart';
import 'package:ecommerce_app/features/checkout/data/services/order_payment_web_console_stub.dart'
    if (dart.library.html) 'package:ecommerce_app/features/checkout/data/services/order_payment_web_console_web.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_payment.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_detail_bundle.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_shipping_info.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_status_history_entry.dart';
import 'package:ecommerce_app/features/order_history/state/order_detail_provider.dart';
import 'package:ecommerce_app/features/order_history/state/order_history_controller.dart';
import 'package:ecommerce_app/features/returns/data/return_record.dart';
import 'package:ecommerce_app/features/returns/data/returns_service.dart';
import 'package:ecommerce_app/features/returns/domain/return_enums.dart';
import 'package:ecommerce_app/features/returns/state/returns_providers.dart';
import 'package:ecommerce_app/presentation/pages/request_return_page.dart';
import 'package:ecommerce_app/presentation/utils/buy_now_navigation.dart';
import 'package:ecommerce_app/core/formatting/estimated_delivery_format.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';
import 'package:ecommerce_app/presentation/widgets/app_network_image.dart';
import 'package:ecommerce_app/presentation/widgets/order_payment_status_badge.dart';
import 'package:ecommerce_app/presentation/widgets/order_status_chip.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        RealtimeChannel,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        SupabaseClient;

class OrderDetailsPage extends ConsumerWidget {
  final String orderId;

  const OrderDetailsPage({
    super.key,
    required this.orderId,
  });

  static const _pipeline = <OrderStatus>[
    OrderStatus.pendingPayment,
    OrderStatus.processing,
    OrderStatus.packed,
    OrderStatus.shipped,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(orderDetailBundleProvider(orderId));

    return asyncDetail.when(
      data: (bundle) => _OrderDetailsBody(
        orderId: orderId,
        bundle: bundle,
        pipeline: _pipeline,
        onAfterCancel: () {
          ref.invalidate(orderDetailBundleProvider(orderId));
          ref.invalidate(orderHistoryControllerProvider);
        },
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const PageLoading(message: 'Loading order...'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: PageErrorState(
          title: 'Could not load order',
          message: e.toString(),
          onRetry: () => ref.invalidate(orderDetailBundleProvider(orderId)),
        ),
      ),
    );
  }
}

class _OrderDetailsBody extends ConsumerStatefulWidget {
  final String orderId;
  final OrderDetailBundle bundle;
  final List<OrderStatus> pipeline;
  final VoidCallback onAfterCancel;

  const _OrderDetailsBody({
    required this.orderId,
    required this.bundle,
    required this.pipeline,
    required this.onAfterCancel,
  });

  @override
  ConsumerState<_OrderDetailsBody> createState() => _OrderDetailsBodyState();
}

class _OrderDetailsBodyState extends ConsumerState<_OrderDetailsBody> {
  bool _cancelling = false;
  bool _retryPaymentBusy = false;
  final GlobalKey _shipmentSectionKey = GlobalKey();
  final GlobalKey _progressSectionKey = GlobalKey();
  RealtimeChannel? _orderRealtimeChannel;
  SupabaseClient? _orderRealtimeClient;

  Order get order => widget.bundle.order;

  OrderItem? get _firstLine =>
      order.items.isEmpty ? null : order.items.first;

  bool get _showRetryPaymentSection =>
      order.paymentMethod == OrderPaymentMethod.razorpay &&
      order.paymentStatus != OrderPaymentStatus.paid;

  String get _retryPaymentMessage =>
      order.paymentStatus == OrderPaymentStatus.failed
          ? 'Payment failed. You can retry payment.'
          : 'Payment is pending. You can complete payment with Razorpay.';

  bool get _retryRazorpayConfigured =>
      ref.read(appEnvProvider).razorpayKeyId.isNotEmpty;

  bool get _legacyShipmentVisible =>
      (order.deliveryMethod == null || order.deliveryMethod!.trim().isEmpty) &&
      (order.courierName != null ||
          order.trackingNumber != null ||
          order.estimatedDeliveryDate != null);

  bool get _showShipmentAwaitingAfterCancel {
    final m = order.deliveryMethod?.trim() ?? '';
    final ds = (order.deliveryStatus ?? '').toLowerCase().trim();
    return m.isEmpty && ds == 'cancelled';
  }

  bool get _showDualDeliverySection {
    final m = order.deliveryMethod?.toLowerCase().trim() ?? '';
    if (m == 'manual_delivery' || m == 'shiprocket_delivery') return true;
    return _showShipmentAwaitingAfterCancel;
  }

  /// Manual partner / phone / delivery status: hide until the order reaches
  /// out-for-delivery (or delivered). Shiprocket + courier-rebook messaging unchanged.
  bool get _showDualDeliveryCard {
    if (!_showDualDeliverySection) return false;
    if (_showShipmentAwaitingAfterCancel) return true;
    final m = order.deliveryMethod?.toLowerCase().trim() ?? '';
    if (m == 'manual_delivery') {
      return order.status == OrderStatus.outForDelivery ||
          order.status == OrderStatus.delivered;
    }
    if (m == 'shiprocket_delivery') return true;
    return false;
  }

  String _humanDeliveryStatusLabel(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'created':
        return 'Created';
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'shipped':
        return 'Shipped';
      case 'in_transit':
        return 'In transit';
      case 'packed':
        return 'Packed';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'rto_initiated':
        return 'RTO initiated';
      case 'rto_completed':
        return 'RTO';
      case 'failed':
        return 'Failed';
      default:
        return (raw == null || raw.trim().isEmpty) ? '—' : raw.trim();
    }
  }

  String _relativeTime(DateTime? at) {
    if (at == null) return '—';
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  void initState() {
    super.initState();
    _subscribeOrderRealtime();
  }

  @override
  void didUpdateWidget(covariant _OrderDetailsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      if (_orderRealtimeChannel != null && _orderRealtimeClient != null) {
        _orderRealtimeClient!.removeChannel(_orderRealtimeChannel!);
        _orderRealtimeChannel = null;
        _orderRealtimeClient = null;
      }
      _subscribeOrderRealtime();
    }
  }

  @override
  void dispose() {
    if (_orderRealtimeChannel != null && _orderRealtimeClient != null) {
      _orderRealtimeClient!.removeChannel(_orderRealtimeChannel!);
      _orderRealtimeChannel = null;
      _orderRealtimeClient = null;
    }
    super.dispose();
  }

  void _subscribeOrderRealtime() {
    final client = ref.read(supabaseClientProvider);
    _orderRealtimeClient = client;
    final channel = client.channel('user-order-${widget.orderId}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.orderId,
      ),
      callback: (_) {
        if (!mounted) return;
        ref.invalidate(orderDetailBundleProvider(widget.orderId));
        ref.invalidate(orderHistoryControllerProvider);
        ref.invalidate(orderReturnsProvider(widget.orderId));
      },
    );
    void refreshReturns() {
      if (!mounted) return;
      ref.invalidate(orderReturnsProvider(widget.orderId));
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'returns',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'order_id',
        value: widget.orderId,
      ),
      callback: (_) => refreshReturns(),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'returns',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'order_id',
        value: widget.orderId,
      ),
      callback: (_) => refreshReturns(),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'returns',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'order_id',
        value: widget.orderId,
      ),
      callback: (_) => refreshReturns(),
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'replacement_cases',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'original_order_id',
        value: widget.orderId,
      ),
      callback: (_) => refreshReturns(),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'replacement_cases',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'original_order_id',
        value: widget.orderId,
      ),
      callback: (_) => refreshReturns(),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'replacement_cases',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'original_order_id',
        value: widget.orderId,
      ),
      callback: (_) => refreshReturns(),
    );

    // Pickup status updates map into ReplacementCase rendering in order-details.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'replacement_pickups',
      callback: (_) => refreshReturns(),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'replacement_pickups',
      callback: (_) => refreshReturns(),
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'replacement_pickups',
      callback: (_) => refreshReturns(),
    );
    channel.subscribe();
    _orderRealtimeChannel = channel;
  }

  Future<void> _refreshOrderDetails() async {
    ref.invalidate(orderDetailBundleProvider(widget.orderId));
    ref.invalidate(orderHistoryControllerProvider);
    await ref.read(orderDetailBundleProvider(widget.orderId).future);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final returnsAsync = ref.watch(orderReturnsProvider(widget.orderId));
    final returnsList = returnsAsync.asData?.value ?? const <ReturnRecord>[];
    final canInstantCancel = order.status == OrderStatus.pendingPayment ||
        order.status == OrderStatus.paymentFailed;
    // Match DB `request_cancel_my_order`: processing or packed only (not yet shipped in order workflow).
    // Do not use shipped_at: Shiprocket booking used to set shipped_at early and hid this button incorrectly.
    final canRequestCancel = order.status == OrderStatus.processing ||
        order.status == OrderStatus.packed;
    final canCancel = canInstantCancel || canRequestCancel;
    final showTrack = order.status == OrderStatus.shipped ||
        order.status == OrderStatus.outForDelivery;
    final dm = order.deliveryMethod?.toLowerCase().trim() ?? '';
    final showShiprocketTrack = dm == 'shiprocket_delivery' &&
        order.trackingUrl != null &&
        order.trackingUrl!.trim().isNotEmpty;
    final hasShipmentSection = _showDualDeliveryCard || _legacyShipmentVisible;
    final showReorderReview = order.status == OrderStatus.delivered;
    final first = _firstLine;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshOrderDetails,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                _OrderHeaderCard(
                  orderId: order.id,
                  status: order.status,
                  orderedAt: order.createdAt,
                ),
                const SizedBox(height: 12),
                _CustomerPaymentInfoCard(order: order),
                if (_showRetryPaymentSection) ...[
                  const SizedBox(height: 12),
                  _RetryPaymentCard(
                    message: _retryPaymentMessage,
                    busy: _retryPaymentBusy,
                    razorpayReady: _retryRazorpayConfigured,
                    onRetry: () => _onRetryPayment(context),
                  ),
                ],
                if (widget.bundle.shipping?.hasStructuredAddress == true) ...[
                  const SizedBox(height: 12),
                  _DeliverToCard(shipping: widget.bundle.shipping!),
                ],
                if (order.status == OrderStatus.cancelRequested) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: scheme.secondaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.hourglass_top_outlined, color: scheme.secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cancellation pending approval. We will notify you when the request is reviewed.',
                              style: TextStyle(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (order.status == OrderStatus.cancelled) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: scheme.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: scheme.error),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Order cancelled',
                                  style: TextStyle(
                                    color: scheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (order.paymentStatus == OrderPaymentStatus.paid &&
                              order.paymentMethod == OrderPaymentMethod.razorpay) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Refund processing (if applicable). Online refunds are initiated automatically; '
                              'timelines depend on your bank or card issuer.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onErrorContainer.withValues(alpha: 0.9),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _progressSectionKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Order progress',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _OrderProgressTracker(
                        current: order.status,
                        pipeline: widget.pipeline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Timeline',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                if (widget.bundle.statusHistory.isEmpty)
                  Text(
                    'No status updates yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.outline,
                        ),
                  )
                else
                  ...widget.bundle.statusHistory.map(
                    (e) => _TimelineEntry(entry: e),
                  ),
                if (_showDualDeliveryCard) ...[
                  const SizedBox(height: 16),
                  Card(
                    key: _shipmentSectionKey,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  size: 20, color: scheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                dm == 'manual_delivery' ? 'Delivery' : 'Shipment',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (dm == 'manual_delivery') ...[
                            if (order.deliveryPartnerName != null)
                              _DetailRow(
                                label: 'Delivery partner',
                                value: order.deliveryPartnerName!,
                              ),
                            if (order.deliveryPartnerPhone != null)
                              _DetailRow(
                                label: 'Partner phone',
                                value: order.deliveryPartnerPhone!,
                              ),
                            _DetailRow(
                              label: 'Delivery status',
                              value: _humanDeliveryStatusLabel(order.deliveryStatus),
                            ),
                          ] else if (dm == 'shiprocket_delivery') ...[
                            if (order.courierName != null)
                              _DetailRow(label: 'Courier', value: order.courierName!),
                            _DetailRow(
                              label: 'Tracking number',
                              value: (order.awbCode != null && order.awbCode!.isNotEmpty)
                                  ? order.awbCode!
                                  : (order.trackingNumber ?? '—'),
                            ),
                            _DetailRow(
                              label: 'Delivery status',
                              value: _humanDeliveryStatusLabel(
                                order.deliveryStatus ?? order.shipmentStatus,
                              ),
                            ),
                            _DetailRow(
                              label: 'Last updated',
                              value: _relativeTime(order.lastTrackingUpdate),
                            ),
                          ] else if (_showShipmentAwaitingAfterCancel) ...[
                            Text(
                              'The courier shipment for this order was cancelled. '
                              'We will set up shipping again — this page updates automatically when tracking is available.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            _DetailRow(
                              label: 'Courier status',
                              value: _humanDeliveryStatusLabel(order.deliveryStatus),
                            ),
                            _DetailRow(
                              label: 'Last updated',
                              value: _relativeTime(order.lastTrackingUpdate),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else if (_legacyShipmentVisible) ...[
                  const SizedBox(height: 16),
                  Card(
                    key: _shipmentSectionKey,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping_outlined,
                                  size: 20, color: scheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Shipment',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (order.courierName != null)
                            _DetailRow(
                                label: 'Courier', value: order.courierName!),
                          if (order.trackingNumber != null)
                            _DetailRow(
                              label: 'Tracking number',
                              value: order.trackingNumber!,
                            ),
                          if (order.estimatedDeliveryDate != null)
                            _DetailRow(
                              label: 'Estimated delivery',
                              value: formatEstimatedDeliveryDate(
                                order.estimatedDeliveryDate!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Items ordered',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OrderLineCard(item: item),
                        _OrderLineReturnRow(
                          order: order,
                          item: item,
                          returnsList: returnsList,
                          onOpenRequest: () async {
                            final oid = item.orderItemId;
                            if (oid == null || oid.isEmpty) return;
                            final done = await Navigator.of(context).pushNamed(
                              '/orders/request-return',
                              arguments: RequestReturnPageArgs(
                                orderId: widget.orderId,
                                orderItemId: oid,
                                productTitle: item.title,
                                productImageUrl: item.imageUrls.isNotEmpty
                                    ? item.imageUrls.first
                                    : null,
                              ),
                            );
                            if (done == true && context.mounted) {
                              ref.invalidate(orderReturnsProvider(widget.orderId));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                returnsAsync.when(
                  data: (list) {
                    if (list.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Return & refund status',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        ...list.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ReturnTrackingCard(record: r),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                if (order.items.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Prices shown are what you paid when you ordered; the listing price may have changed since.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
                if (showReorderReview || showTrack || showShiprocketTrack || canCancel) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (showReorderReview && first != null && first.productId.isNotEmpty)
                        FilledButton.tonalIcon(
                          onPressed: () => openBuyNowCheckout(
                            context,
                            ref,
                            productId: first.productId,
                            quantity: first.quantity < 1 ? 1 : first.quantity,
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                          label: const Text('Buy again'),
                        ),
                      if (showReorderReview && first != null && first.productId.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pushNamed(
                            '/reviews/write',
                            arguments: {
                              'productId': first.productId,
                              'productTitle': first.title,
                            },
                          ),
                          icon: const Icon(Icons.rate_review_outlined, size: 20),
                          label: const Text('Write review'),
                        ),
                      if (showShiprocketTrack)
                        FilledButton.icon(
                          onPressed: () async {
                            final u = Uri.tryParse(order.trackingUrl!.trim());
                            if (u != null && await canLaunchUrl(u)) {
                              await launchUrl(u, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: const Text('Track shipment'),
                        ),
                      if (showTrack)
                        FilledButton.tonalIcon(
                          onPressed: () {
                            final target = hasShipmentSection
                                ? _shipmentSectionKey.currentContext
                                : _progressSectionKey.currentContext;
                            if (target != null) {
                              Scrollable.ensureVisible(
                                target,
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          icon: const Icon(Icons.track_changes_outlined, size: 20),
                          label: const Text('Track order'),
                        ),
                      if (canCancel)
                        OutlinedButton.icon(
                          onPressed: _cancelling
                              ? null
                              : () => _onCancelTap(
                                    context,
                                    requestReview: canRequestCancel,
                                  ),
                          icon: _cancelling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cancel_outlined),
                          label: Text(
                            _cancelling
                                ? (canRequestCancel ? 'Submitting…' : 'Cancelling…')
                                : (canRequestCancel
                                    ? 'Request cancellation'
                                    : 'Cancel order'),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Price details',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _PriceRow(
                          label: 'Items total',
                          value: formatRupee(order.subtotal),
                          valueColor: AppColors.priceText,
                        ),
                        _PriceRow(
                          label: 'Delivery fee',
                          value: (order.deliveryFee ?? 0) <= 0
                              ? 'FREE'
                              : formatRupee(order.deliveryFee!),
                          valueColor: (order.deliveryFee ?? 0) <= 0
                              ? null
                              : AppColors.priceText,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        _PriceRow(
                          label: 'Total paid',
                          value: formatRupee(order.grandTotal),
                          emphasize: true,
                          valueColor: AppColors.priceText,
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _onDownloadInvoice(context),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                      label: const Text('Download Invoice'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Material(
              elevation: 6,
              shadowColor: Colors.black26,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total paid',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      formatRupee(order.grandTotal),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.priceText,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _pollRetryPaymentStatus({
    required String orderId,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final paymentSvc = ref.read(orderPaymentServiceProvider);
    final started = DateTime.now();
    while (DateTime.now().difference(started) < timeout) {
      if (!mounted) return 'pending';
      try {
        if (kIsWeb) {
          orderPaymentWebConsoleLog('Retry polling payment status for: $orderId');
        }
        final status = await paymentSvc.getPaymentStatus(orderId: orderId);
        if (kIsWeb) {
          orderPaymentWebConsoleLog('Retry payment status: $status');
        }
        if (status == 'paid' || status == 'failed') {
          return status;
        }
      } on AuthException {
        rethrow;
      } catch (_) {
        // Keep retry polling active through transient network/edge failures.
      }
      await Future<void>.delayed(const Duration(seconds: 4));
    }
    return 'timeout';
  }

  Future<void> _onRetryPayment(BuildContext context) async {
    if (_retryPaymentBusy) return;
    final env = ref.read(appEnvProvider);
    if (env.razorpayKeyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: Text(
            'Razorpay is not configured. Add RAZORPAY_KEY_ID for this build.',
          ),
        ),
      );
      return;
    }

    setState(() => _retryPaymentBusy = true);
    final svc = RazorpayService(keyId: env.razorpayKeyId);
    final completer = Completer<void>();
    final paymentSvc = ref.read(orderPaymentServiceProvider);
    final supabase = ref.read(supabaseClientProvider);
    var session = supabase.auth.currentSession;
    if (session == null) {
      try {
        final refreshed = await supabase.auth.refreshSession();
        session = refreshed.session ?? supabase.auth.currentSession;
      } catch (_) {
        session = supabase.auth.currentSession;
      }
    }
    if (session == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text('Session expired, please login again'),
          ),
        );
        Navigator.of(context).pushNamed('/login');
      }
      return;
    }
    final ship = widget.bundle.shipping;
    final userEmail = ref.read(authSessionProvider).maybeWhen(
          data: (u) => u == null ? '' : u.email.trim(),
          orElse: () => '',
        );
    final name = (ship?.fullName ?? '').trim().isNotEmpty
        ? ship!.fullName!.trim()
        : 'Customer';
    final phone = (ship?.phone ?? '').trim();

    try {
      String? rzpCheckoutOrderId;
      var paymentResolved = false;
      Future<void> markPaidUi({String? paymentId}) async {
        if (!context.mounted || paymentResolved) return;
        paymentResolved = true;
        ref.invalidate(orderDetailBundleProvider(widget.orderId));
        ref.invalidate(orderHistoryControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text('Payment successful.'),
          ),
        );
        if (!completer.isCompleted) completer.complete();
      }

      Future<void> markFailedUi(String message) async {
        if (!context.mounted || paymentResolved) return;
        paymentResolved = true;
        ref.invalidate(orderDetailBundleProvider(widget.orderId));
        ref.invalidate(orderHistoryControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(message),
          ),
        );
        if (!completer.isCompleted) completer.complete();
      }

      try {
        rzpCheckoutOrderId =
            await paymentSvc.tryCreateRazorpayServerOrder(orderId: widget.orderId);
        if (kIsWeb && (rzpCheckoutOrderId == null || rzpCheckoutOrderId.trim().isEmpty)) {
          throw const RepositoryException(
            'Could not start secure payment session. Please try again.',
          );
        }
        if (rzpCheckoutOrderId != null) {
          try {
            await paymentSvc.setRazorpayCheckoutOrderId(
              orderId: widget.orderId,
              razorpayOrderId: rzpCheckoutOrderId,
            );
          } catch (_) {}
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.fixed,
              content: Text('Could not open payment: $e'),
            ),
          );
        }
        return;
      }

      unawaited(() async {
          try {
            final status = await _pollRetryPaymentStatus(orderId: widget.orderId);
            if (paymentResolved) return;
            if (status == 'paid') {
              await markPaidUi();
              return;
            }
            if (status == 'failed') {
              await markFailedUi('Payment failed. Please try again.');
              return;
            }
            if (status == 'timeout') {
              if (!context.mounted || paymentResolved) return;
              paymentResolved = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.fixed,
                  content: Text('Payment pending, we will update shortly'),
                ),
              );
              if (!completer.isCompleted) completer.complete();
            }
          } on AuthException {
            if (!context.mounted || paymentResolved) return;
            paymentResolved = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.fixed,
                content: Text('Session expired, please login again'),
              ),
            );
            Navigator.of(context).pushNamed('/login');
            if (!completer.isCompleted) completer.complete();
          } catch (_) {
            // Poll loop already tolerates transient failures.
          }
        }());

      svc.openCheckout(
        amountPaise: (order.grandTotal * 100).round(),
        customerName: name,
        customerEmail: userEmail,
        customerContact: phone,
        razorpayOrderId: rzpCheckoutOrderId,
        onPaymentSuccess: (paymentId, razorpayOrderId, razorpaySignature) async {
          if (paymentResolved) return;
          try {
            await paymentSvc.verifyRazorpayPaymentAndMarkPaid(
              orderId: widget.orderId,
              razorpayPaymentId: paymentId,
              razorpayOrderId: razorpayOrderId,
              razorpaySignature: razorpaySignature,
            );
            await markPaidUi(paymentId: paymentId);
          } catch (e) {
            if (context.mounted) {
              if (e is AuthException) {
                paymentResolved = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.fixed,
                    content: Text('Session expired, please login again'),
                  ),
                );
                Navigator.of(context).pushNamed('/login');
                if (!completer.isCompleted) completer.complete();
              }
              // Else: leave unresolved; status polling recovers capture/webhook races.
            }
          }
        },
        onPaymentError: (message) async {
          if (paymentResolved) return;
          final lower = message.toLowerCase();
          final userCancelled = lower.contains('cancel') ||
              lower.contains('dismiss') ||
              lower.contains('closed');
          if (userCancelled) {
            // Soft cancel: keep pending + razorpay_*; polling is source of truth.
            // Never client-mark failed — retry would mint a new Razorpay order
            // while a late capture on the first order can still succeed.
            return;
          }
          if (kIsWeb) {
            // Non-cancel callbacks can be early while UPI collect continues.
            return;
          }
          // Mobile non-cancel: keep pending + poll (parity with web). Hard
          // config/validation errors cannot capture; fail closed immediately.
          if (lower.contains('not configured') ||
              lower.contains('too small to charge') ||
              lower.contains('checkout is not available')) {
            await markFailedUi(message);
            return;
          }
        },
        onPaymentDismissed: () {
          // Modal closed; capture may still complete — leave pending + poll.
        },
        onExternalWallet: (_) {},
      );
      await completer.future;
    } finally {
      svc.dispose();
      if (mounted) setState(() => _retryPaymentBusy = false);
    }
  }

  Future<void> _onDownloadInvoice(BuildContext context) async {
    final order = widget.bundle.order;
    if (order.items.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice cannot be generated.')),
      );
      return;
    }
    try {
      final gen = InvoiceGenerator();
      final bytes = await gen.generateInvoicePdf(
        order,
        order.items,
        shipping: widget.bundle.shipping,
      );
      if (!context.mounted) return;
      await previewInvoicePdf(
        bytes,
        name: 'invoice_${formatOrderIdDisplay(order.id)}',
      );
    } catch (e, st) {
      debugPrint('Invoice: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice cannot be generated.')),
        );
      }
    }
  }

  Future<void> _onCancelTap(BuildContext context, {required bool requestReview}) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(requestReview ? 'Request cancellation' : 'Cancel order'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Keep order'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(requestReview ? 'Submit request' : 'Confirm cancel'),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return;
    if (reason == null) return;

    setState(() => _cancelling = true);
    try {
      if (requestReview) {
        await ref.read(orderHistoryRepositoryProvider).requestOrderCancellation(
              widget.orderId,
              reason: reason.isEmpty ? null : reason,
            );
      } else {
        await ref.read(orderHistoryRepositoryProvider).cancelOrder(
              widget.orderId,
              reason: reason.isEmpty ? null : reason,
            );
      }
      widget.onAfterCancel();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              requestReview
                  ? 'Cancellation request submitted. We will review it shortly.'
                  : 'Order cancelled.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

class _OrderHeaderCard extends StatelessWidget {
  final String orderId;
  final OrderStatus status;
  final DateTime orderedAt;

  const _OrderHeaderCard({
    required this.orderId,
    required this.status,
    required this.orderedAt,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Order ID',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '#${formatOrderIdDisplay(orderId)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              'Status',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            OrderStatusChip(status: status, compact: false, uppercase: true),
            const SizedBox(height: 14),
            Text(
              'Ordered on',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              formatOrderDetailsDateTime(orderedAt),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliverToCard extends StatelessWidget {
  final OrderShippingInfo shipping;

  const _DeliverToCard({required this.shipping});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 22, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Deliver to',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (shipping.fullName != null &&
                shipping.fullName!.trim().isNotEmpty) ...[
              Text(
                shipping.fullName!.trim(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
            ],
            if (shipping.phone != null && shipping.phone!.trim().isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.phone_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shipping.phone!.trim(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (shipping.addressLine != null &&
                shipping.addressLine!.trim().isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.home_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shipping.addressLine!.trim(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Builder(
              builder: (_) {
                final city = shipping.city?.trim() ?? '';
                final pin = shipping.postalCode?.trim() ?? '';
                if (city.isEmpty && pin.isEmpty) return const SizedBox.shrink();
                final line = [
                  if (city.isNotEmpty) city,
                  if (pin.isNotEmpty) pin,
                ].join(' – ');
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 28),
                    Expanded(
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress steps: every milestone up to and including [current] shows a check.
/// The active milestone (e.g. Shipped) pulses slightly; delivered fills all with success styling.
class _OrderProgressTracker extends StatefulWidget {
  final OrderStatus current;
  final List<OrderStatus> pipeline;

  const _OrderProgressTracker({
    required this.current,
    required this.pipeline,
  });

  @override
  State<_OrderProgressTracker> createState() => _OrderProgressTrackerState();
}

class _OrderProgressTrackerState extends State<_OrderProgressTracker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _syncPulse();
  }

  void _syncPulse() {
    final c = widget.current;
    final idx = widget.pipeline.indexOf(c);
    final run = c != OrderStatus.delivered &&
        c != OrderStatus.cancelled &&
        c != OrderStatus.cancelRequested &&
        idx >= 0;
    if (run) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant _OrderProgressTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  _ProgressStepKind _kindForIndex(int i, int idx, bool allDelivered) {
    if (allDelivered) return _ProgressStepKind.completed;
    if (i < idx) return _ProgressStepKind.completed;
    if (i == idx) return _ProgressStepKind.active;
    return _ProgressStepKind.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pipeline = widget.pipeline;
    final current = widget.current;

    if (current == OrderStatus.cancelRequested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _inactivePipeline(context, pipeline),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.hourglass_top_outlined, size: 20, color: scheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cancellation pending approval — shipment is on hold until we respond.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (current == OrderStatus.cancelled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _inactivePipeline(context, pipeline),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.block, size: 20, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order cancelled — progress stopped.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final allDelivered = current == OrderStatus.delivered;
    final idx = pipeline.indexOf(current);

    if (!allDelivered && idx < 0) {
      return _inactivePipeline(context, pipeline);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pipeline.length; i++) ...[
          if (i > 0)
            _ProgressConnector(
              filled: allDelivered || i <= idx,
            ),
          Expanded(
            child: _ProgressStepDot(
              label: pipeline[i].displayLabel,
              kind: _kindForIndex(i, idx, allDelivered),
              pulseScale: _pulseScale,
            ),
          ),
        ],
      ],
    );
  }

  Widget _inactivePipeline(BuildContext context, List<OrderStatus> pipeline) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pipeline.length; i++) ...[
          if (i > 0) const _ProgressConnector(filled: false),
          Expanded(
            child: _ProgressStepDot(
              label: pipeline[i].displayLabel,
              kind: _ProgressStepKind.upcoming,
              pulseScale: const AlwaysStoppedAnimation<double>(1.0),
            ),
          ),
        ],
      ],
    );
  }
}

enum _ProgressStepKind { completed, active, upcoming }

class _ProgressConnector extends StatelessWidget {
  final bool filled;

  const _ProgressConnector({required this.filled});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneColor = scheme.tertiary;
    final track = scheme.outlineVariant.withValues(alpha: 0.9);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        width: 14,
        height: 4,
        decoration: BoxDecoration(
          color: filled ? doneColor : track,
          borderRadius: BorderRadius.circular(3),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: doneColor.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _ProgressStepDot extends StatelessWidget {
  final String label;
  final _ProgressStepKind kind;
  final Animation<double> pulseScale;

  const _ProgressStepDot({
    required this.label,
    required this.kind,
    required this.pulseScale,
  });

  static const double _diameter = 32;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completedFill = Colors.green.shade700;
    final currentFill = scheme.primary;
    final onDark = Colors.white;
    final muted = scheme.surfaceContainerHighest;
    final trackBorder = scheme.outlineVariant;

    final bool showCheck = kind == _ProgressStepKind.completed ||
        kind == _ProgressStepKind.active;
    final bool isActive = kind == _ProgressStepKind.active;

    final Color fill;
    final Color borderColor;
    final double borderWidth;
    final Color textColor;
    final FontWeight labelWeight;

    switch (kind) {
      case _ProgressStepKind.completed:
        fill = completedFill;
        borderColor = Colors.green.shade900;
        borderWidth = 2;
        textColor = Colors.green.shade800;
        labelWeight = FontWeight.w700;
      case _ProgressStepKind.active:
        fill = currentFill;
        borderColor = Color.lerp(currentFill, Colors.black, 0.2)!;
        borderWidth = 2.5;
        textColor = scheme.primary;
        labelWeight = FontWeight.w800;
      case _ProgressStepKind.upcoming:
        fill = muted;
        borderColor = trackBorder;
        borderWidth = 1.5;
        textColor = scheme.onSurfaceVariant;
        labelWeight = FontWeight.w500;
    }

    Widget circle = Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : showCheck && !isActive
                ? [
                    BoxShadow(
                      color: completedFill.withValues(alpha: 0.22),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
      ),
      child: showCheck
          ? Icon(
              isActive ? Icons.local_shipping_rounded : Icons.check_rounded,
              size: 20,
              color: onDark,
            )
          : null,
    );

    if (isActive) {
      circle = AnimatedBuilder(
        animation: pulseScale,
        builder: (context, child) {
          return Transform.scale(scale: pulseScale.value, child: child);
        },
        child: circle,
      );
    }

    return Column(
      children: [
        circle,
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: textColor,
                fontWeight: labelWeight,
                height: 1.15,
              ),
          child: Text(label, textAlign: TextAlign.center, maxLines: 2),
        ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final OrderStatusHistoryEntry entry;

  const _TimelineEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line =
        '${entry.status.displayLabel} — ${formatOrderDetailsDateTime(entry.createdAt)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 8, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.notes!.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPaymentInfoCard extends StatelessWidget {
  final Order order;

  const _CustomerPaymentInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Information',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            _DetailRow(
              label: 'Payment method',
              value: order.paymentMethod.displayLabel,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Payment status',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OrderPaymentStatusBadge(status: order.paymentStatus),
                    ),
                  ),
                ],
              ),
            ),
            if (order.razorpayPaymentId != null &&
                order.razorpayPaymentId!.trim().isNotEmpty)
              _DetailRow(
                label: 'Transaction ID',
                value: order.razorpayPaymentId!.trim(),
              ),
            _DetailRow(
              label: 'Order date',
              value: formatOrderDetailsDateTime(order.createdAt),
            ),
            _DetailRow(
              label: 'Total amount',
              value: formatRupee(order.grandTotal),
              valueColor: AppColors.priceText,
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryPaymentCard extends StatelessWidget {
  final String message;
  final bool busy;
  final bool razorpayReady;
  final VoidCallback onRetry;

  const _RetryPaymentCard({
    required this.message,
    required this.busy,
    required this.razorpayReady,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.errorContainer.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (!razorpayReady) ...[
              const SizedBox(height: 8),
              Text(
                'Add RAZORPAY_KEY_ID (live or test) at build time to enable Razorpay here.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (busy || !razorpayReady) ? null : onRetry,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payment_rounded, size: 20),
              label: Text(busy ? 'Processing…' : 'Retry payment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: body?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: body?.copyWith(
                color: valueColor ?? scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderLineCard extends StatelessWidget {
  final OrderItem item;

  const _OrderLineCard({required this.item});

  static const double _img = 72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = item.imageUrls.isNotEmpty ? item.imageUrls.first : null;
    final canOpen = item.productId.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: canOpen
            ? () => Navigator.of(context).pushNamed(
                  '/catalog/details',
                  arguments: item.productId,
                )
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppNetworkImage(
                imageUrl: url,
                width: _img,
                height: _img,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Qty: ${item.quantity}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Price: ${formatRupee(item.unitPrice)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.priceText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Item total: ${formatRupee(item.lineTotal)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.priceText,
                          ),
                    ),
                    if (canOpen) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Tap to view product',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyLarge;
    final valueStyleBase = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyLarge;
    final valueStyle = valueColor != null
        ? valueStyleBase?.copyWith(color: valueColor)
        : valueStyleBase;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class _OrderLineReturnRow extends StatelessWidget {
  final Order order;
  final OrderItem item;
  final List<ReturnRecord> returnsList;
  final VoidCallback onOpenRequest;

  const _OrderLineReturnRow({
    required this.order,
    required this.item,
    required this.returnsList,
    required this.onOpenRequest,
  });

  @override
  Widget build(BuildContext context) {
    final active = ReturnsService.activeReturnForItem(returnsList, item.orderItemId ?? '');
    if (active != null) return const SizedBox.shrink();
    final block = ReturnsService.customerReturnBlockMessage(
      order: order,
      item: item,
      existingForOrder: returnsList,
    );
    if (block == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onOpenRequest,
            icon: const Icon(Icons.assignment_return_outlined, size: 18),
            label: const Text('Request replacement'),
          ),
        ),
      );
    }
    if (order.status == OrderStatus.delivered) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          block,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ReturnTrackingCard extends StatelessWidget {
  final ReturnRecord record;

  const _ReturnTrackingCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final replacementCase = record.replacementCase;
    final isReplacement = record.returnType == ReturnType.replacement;
    if (isReplacement && replacementCase != null) {
      final forwardStatus = replacementCase.forwardStatus;
      final reverseStatus = replacementCase.reverseStatus;
      final forwardSteps = <_ReturnStep>[
        const _ReturnStep('Replacement approved', true),
        _ReturnStep(
          'Replacement order created',
          _replacementForwardRank(forwardStatus) >= 1,
        ),
        _ReturnStep(
          'Replacement dispatched',
          _replacementForwardRank(forwardStatus) >= 2,
        ),
        _ReturnStep(
          'Replacement delivered',
          _replacementForwardRank(forwardStatus) >= 3,
        ),
      ];
      final reverseSteps = <_ReturnStep>[
        _ReturnStep(
          'Pickup scheduled',
          _replacementReverseRank(reverseStatus) >= 1,
        ),
        _ReturnStep(
          'Pickup in progress',
          _replacementReverseRank(reverseStatus) >= 2,
        ),
        _ReturnStep(
          'Pickup completed',
          _replacementReverseRank(reverseStatus) >= 3,
        ),
      ];

      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Replacement in progress',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Status: ${_replacementStatusLabel(replacementCase.status)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Forward: ${_replacementStatusLabel(forwardStatus)} · Reverse: ${_replacementStatusLabel(reverseStatus)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if ((replacementCase.failureReason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Update: ${replacementCase.failureReason!.trim()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'New item delivery',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...forwardSteps.map((s) => _stepRow(context, s)),
              if ((replacementCase.forwardTrackingUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () async {
                    final u = Uri.tryParse(replacementCase.forwardTrackingUrl!.trim());
                    if (u != null && await canLaunchUrl(u)) {
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Track new item'),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Old item pickup',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...reverseSteps.map((s) => _stepRow(context, s)),
              if ((replacementCase.reverseTrackingUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () async {
                    final u = Uri.tryParse(replacementCase.reverseTrackingUrl!.trim());
                    if (u != null && await canLaunchUrl(u)) {
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Track old item pickup'),
                ),
              ],
              if ((replacementCase.replacementOrderId ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    '/order-details',
                    arguments: replacementCase.replacementOrderId!,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open replacement order'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (record.status == ReturnWorkflowStatus.rejected) {
      return Card(
        margin: EdgeInsets.zero,
        color: scheme.errorContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
              'Replacement declined',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onErrorContainer,
                    ),
              ),
              if (record.rejectionReason != null &&
                  record.rejectionReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  record.rejectionReason!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final refund = record.refund;
    final steps = <_ReturnStep>[
      const _ReturnStep('Return requested', true),
      _ReturnStep(
        'Return approved',
        _refundRank(record.status) >= _refundRank(ReturnWorkflowStatus.approved),
      ),
      _ReturnStep(
        'Item picked up',
        _refundRank(record.status) >= _refundRank(ReturnWorkflowStatus.pickedUp),
      ),
      _ReturnStep(
        'Item returned',
        _refundRank(record.status) >= _refundRank(ReturnWorkflowStatus.returned),
      ),
      _ReturnStep(
        'Refund in progress',
        refund != null,
      ),
      _ReturnStep(
        'Refund completed',
        _refundRank(record.status) >= _refundRank(ReturnWorkflowStatus.refundCompleted),
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Replacement request',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              record.reason.displayLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (record.pickupNotes != null && record.pickupNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Pickup: ${record.pickupNotes!.trim()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (refund != null && refund.status != RefundWorkflowStatus.refundCompleted) ...[
              const SizedBox(height: 8),
              Text(
                'Refund: ${refund.status.displayLabel} · ${formatRupee(refund.refundAmount)} via ${refund.method.displayLabel}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.priceText,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            ...steps.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      s.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: s.done ? scheme.primary : scheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: s.done ? scheme.onSurface : scheme.onSurfaceVariant,
                              fontWeight: s.done ? FontWeight.w600 : FontWeight.w400,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(BuildContext context, _ReturnStep s) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            s.done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: s.done ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: s.done ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: s.done ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  static String _replacementStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'replacement_order_created':
        return 'Replacement order created';
      case 'replacement_dispatched':
        return 'Replacement dispatched';
      case 'replacement_delivered':
        return 'Replacement delivered';
      case 'pickup_scheduled':
        return 'Pickup scheduled';
      case 'pickup_in_progress':
        return 'Pickup in progress';
      case 'pickup_completed':
        return 'Pickup completed';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Action needed';
      default:
        return status;
    }
  }

  static int _replacementForwardRank(String status) {
    switch (status.trim().toLowerCase()) {
      case 'created':
      case 'replacement_order_created':
        return 1;
      case 'in_transit':
      case 'replacement_dispatched':
      case 'out_for_delivery':
        return 2;
      case 'delivered':
      case 'replacement_delivered':
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  static int _replacementReverseRank(String status) {
    switch (status.trim().toLowerCase()) {
      case 'scheduled':
      case 'pickup_scheduled':
        return 1;
      case 'in_transit':
      case 'out_for_pickup':
      case 'pickup_in_progress':
      case 'failed':
        return 2;
      case 'picked_up':
      case 'returned':
      case 'pickup_completed':
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  /// Linear ranks for standard return → refund milestones (not used for replacement flow).
  static int _refundRank(ReturnWorkflowStatus s) {
    switch (s) {
      case ReturnWorkflowStatus.none:
        return -1;
      case ReturnWorkflowStatus.requested:
        return 0;
      case ReturnWorkflowStatus.approved:
        return 1;
      case ReturnWorkflowStatus.pickedUp:
        return 2;
      case ReturnWorkflowStatus.returned:
        return 3;
      case ReturnWorkflowStatus.refundCompleted:
        return 4;
      case ReturnWorkflowStatus.rejected:
        return -1;
    }
  }
}

class _ReturnStep {
  final String label;
  final bool done;

  const _ReturnStep(this.label, this.done);
}
