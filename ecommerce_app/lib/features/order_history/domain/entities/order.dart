import 'order_item.dart';
import 'order_payment.dart';
import 'order_status.dart';

export 'order_payment.dart';
export 'order_status.dart';

class Order {
  final String id;
  final String userId;
  final OrderStatus status;
  final List<OrderItem> items;
  final String currency;
  final DateTime createdAt;
  /// Charged delivery for this order (from checkout RPC). Null for legacy rows.
  final double? deliveryFee;
  final String? trackingNumber;
  final String? courierName;
  final DateTime? estimatedDeliveryDate;
  final OrderPaymentMethod paymentMethod;
  final OrderPaymentStatus paymentStatus;
  final String? razorpayPaymentId;
  /// When the order was marked delivered (return window is 7 days from this).
  final DateTime? deliveredAt;
  /// Last instant a return may be filed; set server-side when delivered.
  final DateTime? returnDeadline;

  const Order({
    required this.id,
    required this.userId,
    required this.status,
    required this.items,
    required this.currency,
    required this.createdAt,
    this.deliveryFee,
    this.trackingNumber,
    this.courierName,
    this.estimatedDeliveryDate,
    this.paymentMethod = OrderPaymentMethod.razorpay,
    this.paymentStatus = OrderPaymentStatus.pending,
    this.razorpayPaymentId,
    this.deliveredAt,
    this.returnDeadline,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get grandTotal => subtotal + (deliveryFee ?? 0);
}

