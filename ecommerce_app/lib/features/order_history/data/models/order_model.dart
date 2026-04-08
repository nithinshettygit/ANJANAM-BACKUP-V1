import 'package:ecommerce_app/core/formatting/estimated_delivery_format.dart';
import 'package:ecommerce_app/core/formatting/inr_format.dart';

import '../../domain/entities/order.dart';
import 'order_item_model.dart';

/// Data model mapped directly to the `orders` table.
class OrderModel {
  final String id;
  final String userId;
  final String status;
  final String currency;
  final DateTime createdAt;
  final double? deliveryFee;
  final String? trackingNumber;
  final String? courierName;
  final DateTime? estimatedDeliveryDate;
  final String? paymentMethodRaw;
  final String? paymentStatusRaw;
  final String? razorpayPaymentId;
  final DateTime? deliveredAt;
  final DateTime? returnDeadline;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.currency,
    required this.createdAt,
    this.deliveryFee,
    this.trackingNumber,
    this.courierName,
    this.estimatedDeliveryDate,
    this.paymentMethodRaw,
    this.paymentStatusRaw,
    this.razorpayPaymentId,
    this.deliveredAt,
    this.returnDeadline,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final estRaw = json['estimated_delivery_date'];
    return OrderModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      status: (json['status'] ?? 'pending_payment').toString(),
      currency: currencyOrInr(json['currency']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      trackingNumber: () {
        final t = json['tracking_number']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      courierName: () {
        final t = json['courier_name']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      estimatedDeliveryDate: parseEstimatedDeliveryFromDb(estRaw),
      paymentMethodRaw: json['payment_method']?.toString(),
      paymentStatusRaw: json['payment_status']?.toString(),
      razorpayPaymentId: () {
        final t = json['razorpay_payment_id']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      deliveredAt: DateTime.tryParse(
        json['delivered_at']?.toString() ?? '',
      ),
      returnDeadline: DateTime.tryParse(
        json['return_deadline']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'status': status,
        'currency': currency,
        'created_at': createdAt.toIso8601String(),
      };

  Order toEntity({
    required List<OrderItemModel> items,
  }) {
    final paymentMethod = orderPaymentMethodFromDb(paymentMethodRaw);
    final paymentStatus = orderPaymentStatusFromDb(paymentStatusRaw);
    var effectiveStatus = OrderStatusX.fromDbValue(status);

    // Guard against legacy/misaligned states: online unpaid orders must not
    // appear as confirmed/processing to customers.
    if (paymentMethod == OrderPaymentMethod.razorpay) {
      if (paymentStatus == OrderPaymentStatus.pending &&
          effectiveStatus == OrderStatus.processing) {
        effectiveStatus = OrderStatus.pendingPayment;
      } else if (paymentStatus == OrderPaymentStatus.failed &&
          effectiveStatus == OrderStatus.processing) {
        effectiveStatus = OrderStatus.paymentFailed;
      }
    }

    return Order(
      id: id,
      userId: userId,
      status: effectiveStatus,
      items: items.map((e) => e.toEntity()).toList(),
      currency: currency,
      createdAt: createdAt,
      deliveryFee: deliveryFee,
      trackingNumber: trackingNumber,
      courierName: courierName,
      estimatedDeliveryDate: estimatedDeliveryDate,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      razorpayPaymentId: razorpayPaymentId,
      deliveredAt: deliveredAt,
      returnDeadline: returnDeadline,
    );
  }
}
