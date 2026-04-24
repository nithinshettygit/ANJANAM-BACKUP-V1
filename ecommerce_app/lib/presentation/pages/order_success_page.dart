import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ecommerce_app/features/notifications/data/services/fcm_edge_function_notification_sender.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/features/notifications/state/notifications_controller.dart';
import 'package:ecommerce_app/features/order_history/state/order_history_controller.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/utils/price_formatter.dart';

class OrderSuccessPage extends ConsumerStatefulWidget {
  final String orderId;
  final double total;
  final String currency;
  /// Set when Razorpay completed and payment id is known.
  final String? razorpayPaymentId;
  /// When true, show both payment + order confirmation lines.
  final bool showOnlinePaymentConfirmed;

  const OrderSuccessPage({
    super.key,
    required this.orderId,
    required this.total,
    required this.currency,
    this.razorpayPaymentId,
    this.showOnlinePaymentConfirmed = false,
  });

  @override
  ConsumerState<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends ConsumerState<OrderSuccessPage> {
  bool _handledNotification = false;

  @override
  void initState() {
    super.initState();
    // Keep "My Orders" up to date when user navigates there from success screen.
    ref.invalidate(orderHistoryControllerProvider);
    unawaited(_handleOrderPlacedNotification());
  }

  Future<void> _handleOrderPlacedNotification() async {
    if (_handledNotification) return;
    _handledNotification = true;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final notificationRow = <String, dynamic>{
      'user_id': user.id,
      'kind': 'order_status',
      'title': 'Order placed',
      'body': 'Your order has been placed successfully.',
      'order_id': widget.orderId,
      'redirect_type': 'order',
      'redirect_value': widget.orderId,
    };

    try {
      final inserted = await client
          .from('user_notifications')
          .insert(notificationRow)
          .select('id')
          .single();

      final notificationId = inserted['id']?.toString();

      ref.invalidate(notificationsControllerProvider);
      ref.invalidate(unreadNotificationsCountProvider);

      await ref.read(fcmNotificationSenderProvider).sendOrderStatusPush(
            userId: user.id,
            orderId: widget.orderId,
            title: 'Order placed',
            message: 'Your order has been placed successfully.',
            kind: 'order_status',
            redirectType: 'order',
            redirectValue: widget.orderId,
            notificationId: notificationId,
          );
    } catch (_) {
      // Best-effort: never break the success page.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showPaymentLine = widget.showOnlinePaymentConfirmed &&
        widget.razorpayPaymentId != null &&
        widget.razorpayPaymentId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(showPaymentLine ? 'Order confirmed' : 'Order placed'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 78,
                  color: scheme.primary,
                ),
                const SizedBox(height: 20),
                if (showPaymentLine) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, color: Colors.green.shade700, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Payment successful',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.green.shade800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_rounded, color: scheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Order placed',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SuccessInfoRow(label: 'Order ID', value: widget.orderId),
                if (showPaymentLine) ...[
                  const SizedBox(height: 12),
                  _SuccessInfoRow(
                    label: 'Payment ID',
                    value: widget.razorpayPaymentId!,
                  ),
                ],
                const SizedBox(height: 12),
                _SuccessInfoRow(
                  label: 'Total amount',
                  value: formatRupee(widget.total),
                  valueColor: AppColors.priceText,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => navigateToCatalogAfterOrder(ref, context),
                    child: const Text('Continue shopping'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/orders',
                      (route) => route.isFirst,
                    ),
                    child: const Text('View my orders'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  ),
                  child: const Text('Back to home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SuccessInfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
