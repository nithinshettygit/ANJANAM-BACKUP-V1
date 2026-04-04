/// Canonical order lifecycle (see migration `034_order_return_refund_lifecycle_checklists.sql`).
enum OrderStatus {
  pendingPayment,
  paymentFailed,
  processing,
  packed,
  shipped,
  outForDelivery,
  delivered,
  cancelRequested,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String toDbValue() {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 'pending_payment';
      case OrderStatus.paymentFailed:
        return 'payment_failed';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.packed:
        return 'packed';
      case OrderStatus.shipped:
        return 'shipped';
      case OrderStatus.outForDelivery:
        return 'out_for_delivery';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelRequested:
        return 'cancel_requested';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  static OrderStatus fromDbValue(String value) {
    final v = value.trim().toLowerCase();
    switch (v) {
      case 'pending_payment':
      case 'placed':
      case 'pending':
        return OrderStatus.pendingPayment;
      case 'payment_failed':
        return OrderStatus.paymentFailed;
      case 'processing':
      case 'confirmed':
      case 'authorized':
      case 'paid':
        return OrderStatus.processing;
      case 'packed':
        return OrderStatus.packed;
      case 'shipped':
        return OrderStatus.shipped;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
      case 'completed':
        return OrderStatus.delivered;
      case 'cancel_requested':
        return OrderStatus.cancelRequested;
      case 'cancelled':
      case 'canceled':
      case 'refunded':
      case 'failed':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pendingPayment;
    }
  }

  String get displayLabel {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 'Pending payment';
      case OrderStatus.paymentFailed:
        return 'Payment failed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.packed:
        return 'Packed';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelRequested:
        return 'Cancellation pending approval';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
