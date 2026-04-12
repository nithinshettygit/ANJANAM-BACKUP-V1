import 'dart:typed_data';

import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_status.dart';
import 'package:ecommerce_app/features/returns/domain/return_enums.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:uuid/uuid.dart';

import 'return_record.dart';

class ReturnsService extends SupabaseServiceBase {
  ReturnsService(super.client);

  static const _returnSelect = 'id, order_id, user_id, product_id, order_item_id, '
      'return_reason, return_note, return_images, return_type, return_status, '
      'pickup_scheduled_at, pickup_notes, rejection_reason, replacement_order_id, '
      'created_at, updated_at, '
      'refunds(id, return_id, order_id, refund_amount, refund_method, refund_status, '
      'payment_transaction_id, created_at, updated_at)';

  Future<List<ReturnRecord>> fetchReturnsForOrder(String orderId) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Sign in required.');
    }
    final data = await guard(
      () => client
          .from('returns')
          .select(_returnSelect)
          .eq('order_id', orderId)
          .eq('user_id', authUser.id)
          .order('created_at', ascending: false),
    );
    final list = (data as List).cast<Map<String, dynamic>>();
    return list.map(ReturnRecord.fromJson).toList();
  }

  /// Public URL after upload to `return-images` bucket.
  Future<String> uploadEvidencePhoto({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Sign in required.');
    }
    final ext = contentType.contains('png') ? 'png' : 'jpg';
    final objectPath = '${authUser.id}/${const Uuid().v4()}.$ext';
    await guard(
      () => client.storage.from('return-images').uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          ),
    );
    return client.storage.from('return-images').getPublicUrl(objectPath);
  }

  Future<String> createReturn({
    required String orderItemId,
    required ReturnReason reason,
    required ReturnType returnType,
    required List<String> imageUrls,
    String? note,
  }) async {
    if (imageUrls.isEmpty) {
      throw const ValidationException('Please add at least one photo of the package / item.');
    }
    try {
      final res = await guard(
        () => client.rpc(
          'create_customer_return',
          params: {
            'p_order_item_id': orderItemId,
            'p_return_reason': reason.dbValue,
            'p_return_note': note ?? '',
            'p_return_images': imageUrls,
            'p_return_type': returnType.dbValue,
          },
        ),
      );
      return res.toString();
    } on RepositoryException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('return_window_expired')) {
        throw const ValidationException(
          'The return window (7 days after delivery) has ended for this order.',
        );
      }
      if (m.contains('return_deadline_missing')) {
        throw const ValidationException(
          'Returns are temporarily unavailable for this order. Please contact support.',
        );
      }
      if (m.contains('order_not_delivered')) {
        throw const ValidationException('Returns are only available for delivered orders.');
      }
      if (m.contains('cancelled_order_not_returnable')) {
        throw const ValidationException('Cancelled orders cannot be returned.');
      }
      if (m.contains('return_already_exists')) {
        throw const ValidationException(
          'A return or replacement is already in progress for this item.',
        );
      }
      if (m.contains('already_refunded')) {
        throw const ValidationException('This item has already been refunded and cannot be returned again.');
      }
      if (m.contains('return_images_required')) {
        throw const ValidationException('At least one photo is required.');
      }
      if (m.contains('not_authorized') || m.contains('order_item_not_found')) {
        throw const ValidationException('We could not submit this return. Check the item and try again.');
      }
      rethrow;
    }
  }

  /// Matches `create_customer_return`: block when [Order.deliveredAt] is older than 7 days (UTC).
  static bool isWithinSevenDayReturnWindow(Order order) {
    final delivered = order.deliveredAt;
    if (delivered == null) return false;
    final nowUtc = DateTime.now().toUtc();
    final deliveredUtc = delivered.toUtc();
    if (deliveredUtc.isBefore(nowUtc.subtract(const Duration(days: 7)))) {
      return false;
    }
    final rd = order.returnDeadline?.toUtc();
    if (rd != null && nowUtc.isAfter(rd)) return false;
    return true;
  }

  /// Non-null when the customer cannot start a return/replace for this line (for UI copy).
  static String? customerReturnBlockMessage({
    required Order order,
    required OrderItem item,
    required List<ReturnRecord> existingForOrder,
  }) {
    if (order.status != OrderStatus.delivered) {
      return 'Returns and replacements are only available after your order is delivered.';
    }
    final oid = item.orderItemId;
    if (oid == null || oid.isEmpty) {
      return 'This item cannot be returned from the app. Please contact support.';
    }
    if (activeReturnForItem(existingForOrder, oid) != null) {
      return 'A return or replacement is already in progress for this item.';
    }
    if (order.deliveredAt == null) {
      return 'We need a confirmed delivery date before you can request a return. Please contact support if this order shows as delivered.';
    }
    if (!isWithinSevenDayReturnWindow(order)) {
      return 'Returns and replacements are only available within 7 days of delivery. That window has closed.';
    }
    return null;
  }

  static bool itemEligibleForNewReturn({
    required Order order,
    required OrderItem item,
    required List<ReturnRecord> existingForOrder,
  }) {
    return customerReturnBlockMessage(
          order: order,
          item: item,
          existingForOrder: existingForOrder,
        ) ==
        null;
  }

  static ReturnRecord? activeReturnForItem(
    List<ReturnRecord> records,
    String orderItemId,
  ) {
    for (final r in records) {
      if (r.orderItemId == orderItemId && r.status != ReturnWorkflowStatus.rejected) {
        return r;
      }
    }
    return null;
  }
}
