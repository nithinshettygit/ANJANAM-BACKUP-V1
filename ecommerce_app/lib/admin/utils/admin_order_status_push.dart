import 'package:ecommerce_app/features/notifications/data/services/fcm_edge_function_notification_sender.dart';

/// Tray / push copy aligned with [AdminOrderNextAction.targetStatusTitleCase].
({String title, String message}) orderStatusPushCopyForTarget(
  String targetStatusTitleCase,
) {
  final t = targetStatusTitleCase.toLowerCase().trim();
  return switch (t) {
    'processing' => (
        title: 'Order confirmed',
        message: 'We are preparing your order.',
      ),
    'payment failed' => (
        title: 'Payment update',
        message: 'Your order payment could not be completed.',
      ),
    'packed' => (
        title: 'Order packed',
        message: 'Your order has been packed and will ship soon.',
      ),
    'shipped' => (
        title: 'Order shipped',
        message: 'Your order is on the way.',
      ),
    'out for delivery' => (
        title: 'Out for delivery',
        message: 'Your order is out for delivery.',
      ),
    'delivered' => (
        title: 'Order delivered',
        message:
            'Your order has been delivered. Thank you for shopping with us!',
      ),
    'cancelled' => (
        title: 'Order cancelled',
        message: 'Your order has been cancelled.',
      ),
    _ => (
        title: 'Order update',
        message: 'Your order status has been updated. Open the app for details.',
      ),
  };
}

/// Best-effort FCM after Postgres already inserted [user_notifications].
/// Never throws — avoids showing "update failed" when only push fails.
Future<void> trySendOrderStatusFcmForTarget(
  FcmEdgeFunctionNotificationSender sender, {
  required String userId,
  required String orderId,
  required String targetStatusTitleCase,
}) async {
  final copy = orderStatusPushCopyForTarget(targetStatusTitleCase);
  try {
    await sender.sendOrderStatusPush(
      userId: userId,
      orderId: orderId,
      title: copy.title,
      message: copy.message,
      kind: 'order_status',
      redirectType: 'order',
      redirectValue: orderId,
    );
  } catch (_) {}
}

Future<void> trySendOrderStatusFcmCustom(
  FcmEdgeFunctionNotificationSender sender, {
  required String userId,
  required String orderId,
  required String title,
  required String message,
}) async {
  try {
    await sender.sendOrderStatusPush(
      userId: userId,
      orderId: orderId,
      title: title,
      message: message,
      kind: 'order_status',
      redirectType: 'order',
      redirectValue: orderId,
    );
  } catch (_) {}
}
