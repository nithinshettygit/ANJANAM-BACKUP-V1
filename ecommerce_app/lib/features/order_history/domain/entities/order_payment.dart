/// How the customer chose to pay (stored on `orders.payment_method`).
enum OrderPaymentMethod {
  razorpay,
  cod,
}

/// Online payment lifecycle (`orders.payment_status`).
enum OrderPaymentStatus {
  paid,
  pending,
  failed,
}

OrderPaymentMethod orderPaymentMethodFromDb(String? raw) {
  switch (raw?.toLowerCase().trim()) {
    case 'cod':
    case 'cash_on_delivery':
    case 'cash on delivery':
    case 'cashondelivery':
      return OrderPaymentMethod.cod;
    default:
      return OrderPaymentMethod.razorpay;
  }
}

OrderPaymentStatus orderPaymentStatusFromDb(String? raw) {
  switch (raw?.toLowerCase().trim()) {
    case 'paid':
      return OrderPaymentStatus.paid;
    case 'failed':
      return OrderPaymentStatus.failed;
    default:
      return OrderPaymentStatus.pending;
  }
}

extension OrderPaymentMethodLabels on OrderPaymentMethod {
  String get displayLabel => switch (this) {
        OrderPaymentMethod.razorpay => 'Razorpay',
        OrderPaymentMethod.cod => 'Cash on Delivery',
      };
}

extension OrderPaymentStatusLabels on OrderPaymentStatus {
  String get displayLabel => switch (this) {
        OrderPaymentStatus.paid => 'Paid',
        OrderPaymentStatus.pending => 'Pending',
        OrderPaymentStatus.failed => 'Failed',
      };
}
