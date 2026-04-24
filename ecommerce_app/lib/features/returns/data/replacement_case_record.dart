class ReplacementPickupRecord {
  final String id;
  final String replacementCaseId;
  final String provider;
  final String status;
  final DateTime? scheduledAt;
  final int attemptNo;
  final String? failureCode;
  final String? failureReason;
  final String? trackingUrl;
  final List<String> proofUrls;
  final DateTime createdAt;

  const ReplacementPickupRecord({
    required this.id,
    required this.replacementCaseId,
    required this.provider,
    required this.status,
    required this.scheduledAt,
    required this.attemptNo,
    this.failureCode,
    this.failureReason,
    this.trackingUrl,
    required this.proofUrls,
    required this.createdAt,
  });

  factory ReplacementPickupRecord.fromJson(Map<String, dynamic> json) {
    final proofRaw = json['proof_urls'];
    final proof = proofRaw is List
        ? proofRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    return ReplacementPickupRecord(
      id: (json['id'] ?? '').toString(),
      replacementCaseId: (json['replacement_case_id'] ?? '').toString(),
      provider: (json['provider'] ?? 'manual').toString(),
      status: (json['status'] ?? 'pickup_scheduled').toString(),
      scheduledAt: DateTime.tryParse(json['scheduled_at']?.toString() ?? ''),
      attemptNo: (json['attempt_no'] as num?)?.toInt() ?? 1,
      failureCode: () {
        final t = json['failure_code']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      failureReason: () {
        final t = json['failure_reason']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      trackingUrl: () {
        final t = json['tracking_url']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      proofUrls: proof,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ReplacementCaseRecord {
  final String id;
  final String returnId;
  final String originalOrderId;
  final String originalOrderItemId;
  final String customerId;
  final String? replacementOrderId;
  final String status;
  final String logisticsMode;
  final String forwardStatus;
  final String reverseStatus;
  final String? forwardShipmentId;
  final String? reverseShipmentId;
  final String? forwardTrackingUrl;
  final String? reverseTrackingUrl;
  final String? failureReason;
  final int attemptCount;
  final DateTime? approvedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final ReplacementPickupRecord? latestPickup;

  const ReplacementCaseRecord({
    required this.id,
    required this.returnId,
    required this.originalOrderId,
    required this.originalOrderItemId,
    required this.customerId,
    required this.replacementOrderId,
    required this.status,
    required this.logisticsMode,
    required this.forwardStatus,
    required this.reverseStatus,
    required this.forwardShipmentId,
    required this.reverseShipmentId,
    required this.forwardTrackingUrl,
    required this.reverseTrackingUrl,
    required this.failureReason,
    required this.attemptCount,
    required this.approvedAt,
    required this.completedAt,
    required this.updatedAt,
    required this.latestPickup,
  });

  factory ReplacementCaseRecord.fromJson(
    Map<String, dynamic> json, {
    ReplacementPickupRecord? latestPickup,
  }) {
    return ReplacementCaseRecord(
      id: (json['id'] ?? '').toString(),
      returnId: (json['return_id'] ?? '').toString(),
      originalOrderId: (json['original_order_id'] ?? '').toString(),
      originalOrderItemId: (json['original_order_item_id'] ?? '').toString(),
      customerId: (json['customer_id'] ?? '').toString(),
      replacementOrderId: () {
        final t = json['replacement_order_id']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      status: (json['status'] ?? 'requested').toString(),
      logisticsMode: (json['logistics_mode'] ?? 'manual').toString(),
      forwardStatus: (json['forward_status'] ?? 'pending').toString(),
      reverseStatus: (json['reverse_status'] ?? 'pending').toString(),
      forwardShipmentId: () {
        final t = json['forward_shipment_id']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      reverseShipmentId: () {
        final t = json['reverse_shipment_id']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      forwardTrackingUrl: () {
        final t = json['forward_tracking_url']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      reverseTrackingUrl: () {
        final t = json['reverse_tracking_url']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      failureReason: () {
        final t = json['failure_reason']?.toString().trim();
        return t != null && t.isNotEmpty ? t : null;
      }(),
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      approvedAt: DateTime.tryParse(json['approved_at']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      latestPickup: latestPickup,
    );
  }
}
