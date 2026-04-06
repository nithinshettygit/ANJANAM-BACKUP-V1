import '../domain/return_enums.dart';

class RefundRecord {
  final String id;
  final String returnId;
  final String orderId;
  final double refundAmount;
  final RefundMethod method;
  final RefundWorkflowStatus status;
  final String? paymentTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RefundRecord({
    required this.id,
    required this.returnId,
    required this.orderId,
    required this.refundAmount,
    required this.method,
    required this.status,
    this.paymentTransactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RefundRecord.fromJson(Map<String, dynamic> json) {
    return RefundRecord(
      id: (json['id'] ?? '').toString(),
      returnId: (json['return_id'] ?? json['returnId'] ?? '').toString(),
      orderId: (json['order_id'] ?? '').toString(),
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      method: RefundMethod.tryParse(json['refund_method']?.toString()) ??
          RefundMethod.originalPayment,
      status: RefundWorkflowStatus.tryParse(json['refund_status']?.toString()) ??
          RefundWorkflowStatus.refundInitiated,
      paymentTransactionId: () {
        final t = json['payment_transaction_id']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ReturnRecord {
  final String id;
  final String orderId;
  final String userId;
  final String productId;
  final String orderItemId;
  final ReturnReason reason;
  final String? returnNote;
  final List<String> returnImages;
  final ReturnType returnType;
  final ReturnWorkflowStatus status;
  final DateTime? pickupScheduledAt;
  final String? pickupNotes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RefundRecord? refund;
  final String? replacementOrderId;

  const ReturnRecord({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.productId,
    required this.orderItemId,
    required this.reason,
    required this.returnNote,
    required this.returnImages,
    required this.returnType,
    required this.status,
    required this.pickupScheduledAt,
    required this.pickupNotes,
    required this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.refund,
    this.replacementOrderId,
  });

  static List<Map<String, dynamic>>? _refundsList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (raw is Map) {
      return [Map<String, dynamic>.from(raw)];
    }
    return null;
  }

  factory ReturnRecord.fromJson(Map<String, dynamic> json) {
    RefundRecord? refund;
    final nested = _refundsList(json['refunds']);
    if (nested != null && nested.isNotEmpty) {
      refund = RefundRecord.fromJson(nested.first);
    }

    final imgs = json['return_images'];
    final imageList = imgs is List
        ? imgs.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];

    return ReturnRecord(
      id: (json['id'] ?? '').toString(),
      orderId: (json['order_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      orderItemId: (json['order_item_id'] ?? '').toString(),
      reason: ReturnReason.tryParse(json['return_reason']?.toString()) ??
          ReturnReason.damagedItem,
      returnNote: () {
        final t = json['return_note']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      returnImages: imageList,
      returnType: ReturnType.tryParse(json['return_type']?.toString()) ??
          ReturnType.returnItem,
      status: ReturnWorkflowStatus.tryParse(json['return_status']?.toString()) ??
          ReturnWorkflowStatus.requested,
      pickupScheduledAt:
          DateTime.tryParse(json['pickup_scheduled_at']?.toString() ?? ''),
      pickupNotes: () {
        final t = json['pickup_notes']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      rejectionReason: () {
        final t = json['rejection_reason']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      refund: refund,
      replacementOrderId: () {
        final t = json['replacement_order_id']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
    );
  }
}
