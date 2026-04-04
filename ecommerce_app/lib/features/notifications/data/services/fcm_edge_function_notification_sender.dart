import 'dart:convert';

import 'package:ecommerce_app/core/config/app_env.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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
  final AppEnv env;

  const FcmEdgeFunctionNotificationSender({
    required this.client,
    required this.env,
  });

  FcmSendResult _parseOrThrow(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Notification request failed (${res.statusCode}).');
      }
      return const FcmSendResult(attempted: 0, success: 0, failure: 0);
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final err = json['error']?.toString() ?? 'request_failed';
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
      if (attempted > 0 && failure > 0) {
        final failures = fcm['failures'];
        String? detail;
        if (failures is List && failures.isNotEmpty) {
          final first = failures.first;
          if (first is Map && first['detail'] != null) {
            detail = first['detail'].toString();
          }
        }
        throw Exception(
          detail == null || detail.isEmpty
              ? 'FCM delivery failed for $failure/$attempted token(s).'
              : 'FCM delivery failed for $failure/$attempted token(s): $detail',
        );
      }

      return FcmSendResult(
        attempted: attempted,
        success: success,
        failure: failure,
        note: note,
      );
    }

    return FcmSendResult(
      attempted: 0,
      success: 0,
      failure: 0,
      note: note,
    );
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
    final baseUrl = env.supabaseFunctionsBaseUrl.trim();
    if (baseUrl.isEmpty) {
      return const FcmSendResult(attempted: 0, success: 0, failure: 0);
    } // Not configured.

    final accessToken = client.auth.currentSession?.accessToken;
    final endpoint = Uri.parse('$baseUrl/send-notification');

    final payload = <String, dynamic>{
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
    };

    final res = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );

    return _parseOrThrow(res);
  }

  Future<FcmSendResult> sendUserNotification({
    required String title,
    required String message,
    required String kind,
    required String redirectType,
    required String redirectValue,
    required bool broadcast,
    String? userId,
  }) async {
    final baseUrl = env.supabaseFunctionsBaseUrl.trim();
    if (baseUrl.isEmpty) {
      return const FcmSendResult(attempted: 0, success: 0, failure: 0);
    }

    final accessToken = client.auth.currentSession?.accessToken;
    final endpoint = Uri.parse('$baseUrl/send-notification');

    final payload = <String, dynamic>{
      'action': 'user_notification',
      'title': title,
      'message': message,
      'kind': kind,
      'redirect_type': redirectType,
      'redirect_value': redirectValue,
      'broadcast': broadcast,
      if (!broadcast) 'user_id': userId ?? '',
    };

    final res = await http.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );

    return _parseOrThrow(res);
  }
}

/// Provider so widgets/controllers can call the sender easily.
final fcmNotificationSenderProvider = Provider<FcmEdgeFunctionNotificationSender>(
  (ref) => FcmEdgeFunctionNotificationSender(
    client: ref.watch(supabaseClientProvider),
    env: ref.watch(appEnvProvider),
  ),
);

