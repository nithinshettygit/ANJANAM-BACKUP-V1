import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmSendResult {
  final int attempted;
  final int success;
  final int failure;
  final String? note;

  const FcmSendResult({
    required this.attempted,
    required this.success,
    required this.failure,
    this.note,
  });
}

class FcmEdgeFunctionNotificationSender {
  final SupabaseClient client;

  const FcmEdgeFunctionNotificationSender({
    required this.client,
  });

  static String _trimBody(Object? data) {
    if (data == null) return '';
    final s = data.toString().trim();
    if (s.length <= 400) return s;
    return '${s.substring(0, 400)}…';
  }

  FcmSendResult _parseFunctionResponse(int status, dynamic data) {
    Map<String, dynamic>? json;
    if (data is Map) {
      json = Map<String, dynamic>.from(data);
    }

    if (json == null) {
      if (status < 200 || status >= 300) {
        throw Exception(
          'Notification request failed (HTTP $status). ${_trimBody(data)}',
        );
      }
      return const FcmSendResult(attempted: 0, success: 0, failure: 0);
    }

    if (status < 200 || status >= 300) {
      final err = json['error']?.toString().trim().isNotEmpty == true
          ? json['error'].toString()
          : json['message']?.toString().trim().isNotEmpty == true
              ? json['message'].toString()
              : json['msg']?.toString().trim().isNotEmpty == true
                  ? json['msg'].toString()
                  : 'HTTP $status';
      final detail = json['detail']?.toString();
      throw Exception(
        detail == null || detail.isEmpty
            ? 'Notification request failed: $err'
            : 'Notification request failed: $err ($detail)',
      );
    }

    final fcm = json['fcm'];
    final note = json['note']?.toString();
    if (fcm is Map) {
      final failure = (fcm['failure'] as num?)?.toInt() ?? 0;
      final attempted = (fcm['attempted'] as num?)?.toInt() ?? 0;
      final success = (fcm['success'] as num?)?.toInt() ?? 0;
      String? mergedNote = note;
      if (attempted > 0 && failure > 0) {
        final failures = fcm['failures'];
        String? detail;
        if (failures is List && failures.isNotEmpty) {
          final first = failures.first;
          if (first is Map && first['detail'] != null) {
            detail = first['detail'].toString();
            if (detail.length > 280) {
              detail = '${detail.substring(0, 280)}…';
            }
          }
        }
        final pushHint = detail == null || detail.isEmpty
            ? '$failure of $attempted push token(s) failed (stale or invalid FCM tokens).'
            : '$failure of $attempted push token(s) failed: $detail';
        mergedNote = mergedNote == null || mergedNote.isEmpty
            ? pushHint
            : '$mergedNote $pushHint';
      }

      return FcmSendResult(
        attempted: attempted,
        success: success,
        failure: failure,
        note: mergedNote,
      );
    }

    return FcmSendResult(
      attempted: 0,
      success: 0,
      failure: 0,
      note: note,
    );
  }

  Future<FcmSendResult> _invokeSendNotification(Map<String, dynamic> body) async {
    try {
      await client.auth.refreshSession();
    } catch (_) {}

    if (client.auth.currentSession == null) {
      throw Exception('Sign in required to send notifications.');
    }

    // Do not pass a custom `Authorization` header. `functions.invoke` uses
    // [AuthHttpClient], which sets `Authorization` via `putIfAbsent` only when
    // missing — a manual Bearer token bypasses session refresh and causes
    // 401 Invalid JWT after the access token expires (common on long-lived web tabs).
    try {
      final res = await client.functions.invoke(
        'send-notification',
        body: body,
      );
      return _parseFunctionResponse(res.status, res.data);
    } on FunctionException catch (e) {
      return _parseFunctionResponse(e.status, e.details);
    }
  }

  Future<FcmSendResult> sendOrderStatusPush({
    required String userId,
    required String orderId,
    required String title,
    required String message,
    required String kind,
    required String redirectType,
    required String redirectValue,
    String? notificationId,
  }) async {
    return _invokeSendNotification({
      'action': 'order_status',
      'user_id': userId,
      'order_id': orderId,
      'kind': kind,
      'title': title,
      'message': message,
      'redirect_type': redirectType,
      'redirect_value': redirectValue,
      if (notificationId != null && notificationId.trim().isNotEmpty)
        'notification_id': notificationId,
    });
  }

  Future<FcmSendResult> sendUserNotification({
    required String title,
    required String message,
    required String kind,
    required String redirectType,
    required String redirectValue,
    required bool broadcast,
    String? userId,
    String? imageUrl,
  }) async {
    return _invokeSendNotification({
      'action': 'user_notification',
      'title': title,
      'message': message,
      'kind': kind,
      'redirect_type': redirectType,
      'redirect_value': redirectValue,
      if (imageUrl != null && imageUrl.trim().isNotEmpty) 'image_url': imageUrl.trim(),
      'broadcast': broadcast,
      if (!broadcast) 'user_id': userId ?? '',
    });
  }
}

/// Provider so widgets/controllers can call the sender easily.
final fcmNotificationSenderProvider = Provider<FcmEdgeFunctionNotificationSender>(
  (ref) => FcmEdgeFunctionNotificationSender(
    client: ref.watch(supabaseClientProvider),
  ),
);
