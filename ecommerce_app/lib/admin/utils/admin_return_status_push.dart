import 'package:ecommerce_app/features/notifications/data/services/fcm_edge_function_notification_sender.dart';

({String title, String message}) replacementStatusPushCopyForStatus(String status) {
  final s = status.trim().toLowerCase();
  return switch (s) {
    'requested' => (
        title: 'Replacement requested',
        message: 'We received your replacement request and will review it soon.',
      ),
    'approved' => (
        title: 'Replacement approved',
        message: 'Your replacement request has been approved.',
      ),
    'rejected' => (
        title: 'Replacement rejected',
        message: 'Your replacement request was rejected. Open the app for details.',
      ),
    'picked_up' => (
        title: 'Replacement pickup completed',
        message: 'Your item has been picked up for replacement processing.',
      ),
    'returned' => (
        title: 'Replacement item received',
        message: 'Your item has been received and verified for replacement.',
      ),
    'replacement_order_created' => (
        title: 'Replacement order created',
        message: 'Your replacement order is created and will be dispatched soon.',
      ),
    'replacement_dispatched' => (
        title: 'Replacement dispatched',
        message: 'Your replacement item has been dispatched.',
      ),
    'replacement_delivered' => (
        title: 'Replacement delivered',
        message: 'Your replacement item has been delivered.',
      ),
    'pickup_scheduled' => (
        title: 'Pickup scheduled',
        message: 'Pickup for the original item has been scheduled.',
      ),
    'pickup_in_progress' => (
        title: 'Pickup in progress',
        message: 'Courier is attempting pickup for your original item.',
      ),
    'pickup_completed' => (
        title: 'Pickup completed',
        message: 'Original item pickup is completed.',
      ),
    'failed' => (
        title: 'Replacement update required',
        message: 'Pickup failed and will be retried. Open the app for details.',
      ),
    'completed' => (
        title: 'Replacement completed',
        message: 'Replacement delivery and pickup are both completed.',
      ),
    'refund_completed' => (
        title: 'Replacement refund processed',
        message: 'Refund for your replacement request has been completed.',
      ),
    _ => (
        title: 'Replacement update',
        message: 'Your replacement status has been updated. Open the app for details.',
      ),
  };
}

Future<void> trySendReplacementStatusFcm(
  FcmEdgeFunctionNotificationSender sender, {
  required String userId,
  required String orderId,
  required String status,
}) async {
  final copy = replacementStatusPushCopyForStatus(status);
  try {
    await sender.sendOrderStatusPush(
      userId: userId,
      orderId: orderId,
      title: copy.title,
      message: copy.message,
      kind: 'return_refund',
      redirectType: 'order',
      redirectValue: orderId,
    );
  } catch (_) {}
}

