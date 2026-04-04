import 'package:flutter/material.dart';

/// Normalizes raw DB/UI order status for admin lifecycle checks.
String canonicalAdminOrderStatus(String raw) {
  final v = raw.trim().toLowerCase();
  if (v == 'pending' || v == 'placed') return 'pending_payment';
  if (v == 'cancel requested' || v == 'cancellation pending') return 'cancel_requested';
  return v;
}

/// One allowed admin transition from the current order status.
class AdminOrderNextAction {
  final String buttonLabel;
  /// Passed to [AdminService.updateOrderStatus] (Title Case or phrase); normalized server-side.
  final String targetStatusTitleCase;
  final String confirmationTitle;
  final String confirmationBody;
  final bool destructive;

  const AdminOrderNextAction({
    required this.buttonLabel,
    required this.targetStatusTitleCase,
    required this.confirmationTitle,
    required this.confirmationBody,
    this.destructive = false,
  });
}

/// Valid next actions only (strict lifecycle).
List<AdminOrderNextAction> adminOrderNextActions(String rawStatus) {
  switch (canonicalAdminOrderStatus(rawStatus)) {
    case 'pending_payment':
      return const [
        AdminOrderNextAction(
          buttonLabel: 'Mark as Processing',
          targetStatusTitleCase: 'Processing',
          confirmationTitle: 'Mark as Processing',
          confirmationBody:
              'Confirm payment is verified and the order can move to processing.',
        ),
        AdminOrderNextAction(
          buttonLabel: 'Mark payment failed',
          targetStatusTitleCase: 'Payment failed',
          confirmationTitle: 'Mark payment failed',
          confirmationBody:
              'Use this when online payment did not complete successfully.',
        ),
        AdminOrderNextAction(
          buttonLabel: 'Cancel order',
          targetStatusTitleCase: 'Cancelled',
          confirmationTitle: 'Cancel order',
          confirmationBody:
              'Cancel this order before it is packed or shipped.',
          destructive: true,
        ),
      ];
    case 'payment_failed':
      return const [
        AdminOrderNextAction(
          buttonLabel: 'Cancel order',
          targetStatusTitleCase: 'Cancelled',
          confirmationTitle: 'Cancel order',
          confirmationBody: 'Cancel this failed-payment order.',
          destructive: true,
        ),
      ];
    case 'processing':
      return const [
        AdminOrderNextAction(
          buttonLabel: 'Mark as Packed',
          targetStatusTitleCase: 'Packed',
          confirmationTitle: 'Mark as Packed',
          confirmationBody:
              'Confirm items are packed and inventory is correct.',
        ),
        AdminOrderNextAction(
          buttonLabel: 'Cancel order',
          targetStatusTitleCase: 'Cancelled',
          confirmationTitle: 'Cancel order',
          confirmationBody:
              'Cancel before shipment. Use only if appropriate.',
          destructive: true,
        ),
      ];
    case 'packed':
      return const [
        AdminOrderNextAction(
          buttonLabel: 'Mark as Shipped',
          targetStatusTitleCase: 'Shipped',
          confirmationTitle: 'Mark as Shipped',
          confirmationBody:
              'Requires tracking, courier, package weight and dimensions saved on the order first.',
        ),
        AdminOrderNextAction(
          buttonLabel: 'Cancel order',
          targetStatusTitleCase: 'Cancelled',
          confirmationTitle: 'Cancel order',
          confirmationBody: 'Cancel before dispatch.',
          destructive: true,
        ),
      ];
    case 'shipped':
      return const [
        AdminOrderNextAction(
          buttonLabel: 'Mark out for delivery',
          targetStatusTitleCase: 'Out for delivery',
          confirmationTitle: 'Out for delivery',
          confirmationBody:
              'Mark the order as out for delivery.',
        ),
      ];
    case 'out_for_delivery':
      return const [
        AdminOrderNextAction(
          buttonLabel: 'Mark as Delivered',
          targetStatusTitleCase: 'Delivered',
          confirmationTitle: 'Mark as Delivered',
          confirmationBody:
              'Confirm delivery with the customer.',
        ),
      ];
    case 'delivered':
    case 'cancelled':
    case 'cancel_requested':
      return const [];
    default:
      return const [];
  }
}

/// Returns `null` if the admin cancelled. Otherwise returns optional note (empty → `null` for RPC).
Future<String?> showAdminOrderStatusConfirmDialog(
  BuildContext context, {
  required AdminOrderNextAction action,
}) async {
  final noteCtrl = TextEditingController();
  try {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(action.confirmationTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(action.confirmationBody),
                const SizedBox(height: 16),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Optional note',
                    hintText: 'e.g. Packed and handed to courier',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: action.destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return null;
    final trimmed = noteCtrl.text.trim();
    return trimmed.isEmpty ? '' : trimmed;
  } finally {
    noteCtrl.dispose();
  }
}

String adminOrderActionSuccessMessage(AdminOrderNextAction action) {
  if (action.targetStatusTitleCase.toLowerCase() == 'cancelled') {
    return 'Order cancelled successfully.';
  }
  return 'Order marked as ${action.targetStatusTitleCase} successfully.';
}
