import 'dart:developer' as developer;
import 'dart:convert';

import 'package:ecommerce_app/core/config/app_env.dart';
import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Persists Razorpay outcome: successful checkouts use
/// [verifyRazorpayPaymentAndMarkPaid] (Edge Function: signature + payment API).
/// Failures still use [update_order_payment_status].
class OrderPaymentService extends SupabaseServiceBase {
  OrderPaymentService(super.client);

  Future<({int status, dynamic data})> _invokeVerifyPaymentNoPreflightWeb({
    required Map<String, dynamic> body,
  }) async {
    final base = AppEnv.resolve().supabaseFunctionsBaseUrl.trim();
    if (base.isEmpty) {
      throw const RepositoryException('Missing Supabase functions base URL.');
    }
    final uri = Uri.parse('$base/verify_payment');
    // Keep this as a CORS-safelisted request (text/plain, no custom headers)
    // so web clients can bypass broken OPTIONS preflight at the gateway.
    final res = await http.post(
      uri,
      headers: const <String, String>{'Content-Type': 'text/plain'},
      body: jsonEncode(body),
    );
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      data = <String, dynamic>{'raw': res.body};
    }
    return (status: res.statusCode, data: data);
  }

  Future<({int status, dynamic data})> _invokeCreatePaymentOrderNoPreflightWeb({
    required Map<String, dynamic> body,
  }) async {
    final base = AppEnv.resolve().supabaseFunctionsBaseUrl.trim();
    if (base.isEmpty) {
      throw const RepositoryException('Missing Supabase functions base URL.');
    }
    final uri = Uri.parse('$base/create_payment_order');
    final res = await http.post(
      uri,
      headers: const <String, String>{'Content-Type': 'text/plain'},
      body: jsonEncode(body),
    );
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      data = <String, dynamic>{'raw': res.body};
    }
    return (status: res.statusCode, data: data);
  }

  static bool _functionPathNotFound(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('404') ||
        t.contains('not found') ||
        t.contains('requested function was not found');
  }

  /// Creates a Razorpay Order (`order_...`) via Edge Function.
  ///
  /// Uses `create_payment_order` (production name), and transparently falls back to
  /// `create-razorpay-order` for backward compatibility.
  Future<String?> tryCreateRazorpayServerOrder({required String orderId}) async {
    try {
      await client.auth.refreshSession();
    } catch (_) {}
    final accessToken = client.auth.currentSession?.accessToken.trim() ?? '';
    final userId = client.auth.currentUser?.id.trim() ?? '';
    if (accessToken.isEmpty) {
      throw const AuthException('Sign in required.');
    }
    if (userId.isEmpty) {
      throw const AuthException('Sign in required.');
    }
    try {
      final body = <String, dynamic>{'order_id': orderId, 'user_id': userId};
      late final int status;
      late final dynamic data;
      if (kIsWeb) {
        final res = await _invokeCreatePaymentOrderNoPreflightWeb(body: body);
        status = res.status;
        data = res.data;
      } else {
        final res = await client.functions.invoke(
          'create_payment_order',
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
          },
          body: body,
        );
        status = res.status;
        data = res.data;
      }
      var fallbackStatus = status;
      var fallbackData = data;
      if (fallbackStatus == 404) {
        final res = await client.functions.invoke(
          'create-razorpay-order',
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
          },
          body: body,
        );
        fallbackStatus = res.status;
        fallbackData = res.data;
      }
      if (fallbackStatus == 404) {
        developer.log(
          'Edge Function create_payment_order returned 404 (not deployed?). '
          'Using Razorpay checkout without server order_id.',
          name: 'OrderPaymentService',
        );
        return null;
      }
      if (fallbackStatus < 200 || fallbackStatus >= 300) {
        final err =
            (fallbackData is Map ? fallbackData['error']?.toString() : null) ??
            'invoke_failed';
        final detail =
            (fallbackData is Map ? fallbackData['detail']?.toString() : null) ??
            '';
        throw RepositoryException(
          detail.isEmpty ? 'Could not start payment ($err).' : 'Could not start payment ($err): $detail',
        );
      }
      if (fallbackData is Map) {
        final id = fallbackData['razorpay_order_id']?.toString().trim();
        if (id != null && id.isNotEmpty) return id;
      }
      throw const RepositoryException('Could not start payment (missing order id).');
    } on AuthException {
      rethrow;
    } catch (e) {
      if (e is RepositoryException) rethrow;
      final msg = e.toString().toLowerCase();
      // Browser blocks cross-origin Edge Function calls without CORS (shows as ClientException: Failed to fetch).
      if (msg.contains('failed to fetch')) {
        developer.log(
          'create_payment_order: network/CORS blocked (redeploy Edge Function with CORS headers). '
          'Falling back to Razorpay checkout without server order_id.',
          name: 'OrderPaymentService',
        );
        return null;
      }
      if (msg.contains('status 401') || msg.contains('unauthorized')) {
        throw const RepositoryException(
          'Could not start payment (auth). Please sign in again and retry.',
        );
      }
      if (_functionPathNotFound(e)) {
        developer.log(
          'create_payment_order unavailable ($e). Opening Razorpay without server order_id.',
          name: 'OrderPaymentService',
        );
        return null;
      }
      rethrow;
    }
  }

  /// Persists Razorpay `order_...` on the row while checkout is still pending.
  Future<void> setRazorpayCheckoutOrderId({
    required String orderId,
    required String razorpayOrderId,
  }) async {
    try {
      await client.rpc(
        'set_razorpay_checkout_order_id',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_razorpay_order_id': razorpayOrderId,
        },
      );
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('not_authenticated')) {
        throw const AuthException('Sign in required.');
      }
      if (m.contains('order_not_found_or_forbidden')) {
        throw const ValidationException('Could not link payment to this order.');
      }
      if (m.contains('invalid_razorpay_order_id')) {
        throw const ValidationException('Invalid payment session.');
      }
      throw RepositoryException(e.message.trim().isNotEmpty ? e.message : e.toString());
    }
  }

  /// Verifies payment on the server (`verify_payment` Edge Function): Razorpay API check,
  /// HMAC of `order_id|payment_id` when a Razorpay order exists, then sets `payment_status` paid.
  Future<void> verifyRazorpayPaymentAndMarkPaid({
    required String orderId,
    required String razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    try {
      await client.auth.refreshSession();
    } catch (_) {}
    final accessToken = client.auth.currentSession?.accessToken.trim() ?? '';
    final userId = client.auth.currentUser?.id.trim() ?? '';
    if (accessToken.isEmpty) {
      throw const AuthException('Sign in required.');
    }
    if (userId.isEmpty) {
      throw const AuthException('Sign in required.');
    }
    final body = <String, dynamic>{
      'order_id': orderId,
      'user_id': userId,
      'razorpay_payment_id': razorpayPaymentId.trim(),
      if (razorpayOrderId != null && razorpayOrderId.trim().isNotEmpty)
        'razorpay_order_id': razorpayOrderId.trim(),
      if (razorpaySignature != null && razorpaySignature.trim().isNotEmpty)
        'razorpay_signature': razorpaySignature.trim(),
    };
    try {
      // Production canonical function name is `verify_payment`.
      // Keep legacy fallback for older deployments still using dashed naming.
      const primaryVerifyFn = 'verify_payment';
      const fallbackVerifyFn = 'verify-razorpay-payment';

      late final int status;
      late final dynamic data;
      if (kIsWeb) {
        final res = await _invokeVerifyPaymentNoPreflightWeb(body: body);
        status = res.status;
        data = res.data;
      } else {
        final res = await client.functions.invoke(
          primaryVerifyFn,
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
          },
          body: body,
        );
        status = res.status;
        data = res.data;
      }
      var fallbackStatus = status;
      var fallbackData = data;
      if (fallbackStatus == 404) {
        final res = await client.functions.invoke(
          fallbackVerifyFn,
          headers: <String, String>{
            'Authorization': 'Bearer $accessToken',
          },
          body: body,
        );
        fallbackStatus = res.status;
        fallbackData = res.data;
      }
      if (fallbackStatus == 404) {
        throw const RepositoryException(
          'Payment verification is not deployed. Deploy the verify_payment Edge Function.',
        );
      }
      if (fallbackStatus < 200 || fallbackStatus >= 300) {
        final err =
            (fallbackData is Map ? fallbackData['error']?.toString() : null) ??
            'verify_failed';
        final detail =
            (fallbackData is Map ? fallbackData['detail']?.toString() : null) ??
            '';
        throw RepositoryException(
          detail.isEmpty
              ? 'Could not verify payment ($err).'
              : 'Could not verify payment ($err): $detail',
        );
      }
      if (fallbackData is Map && fallbackData['ok'] == true) return;
      throw const RepositoryException('Could not verify payment.');
    } on AuthException {
      rethrow;
    } on RepositoryException {
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('failed to fetch')) {
        throw const RepositoryException(
          'Could not reach payment verification (network or CORS). '
          'Deploy verify_payment with CORS headers, same as other Razorpay functions.',
        );
      }
      if (msg.contains('status 401') || msg.contains('unauthorized')) {
        throw const RepositoryException(
          'Payment verification failed (auth). Please sign in again and retry.',
        );
      }
      rethrow;
    }
  }

  Future<void> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
    String? razorpayPaymentId,
    String? razorpayOrderId,
  }) async {
    try {
      await client.rpc(
        'update_order_payment_status',
        params: <String, dynamic>{
          'p_order_id': orderId,
          'p_payment_status': paymentStatus,
          'p_razorpay_payment_id': razorpayPaymentId,
          'p_razorpay_order_id': razorpayOrderId,
        },
      );
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('not_authenticated')) {
        throw const AuthException('Sign in required.');
      }
      if (m.contains('order_not_found') || m.contains('forbidden')) {
        throw const ValidationException('Could not update this order.');
      }
      if (m.contains('invalid_payment_status')) {
        throw const ValidationException('Invalid payment status.');
      }
      if (m.contains('razorpay_payment_id_required')) {
        throw const ValidationException('Missing payment reference.');
      }
      throw RepositoryException(e.message.trim().isNotEmpty ? e.message : e.toString());
    }
  }

  /// Marks the order as cash-on-delivery ([set_order_payment_cod] RPC).
  Future<void> setOrderPaymentCod({required String orderId}) async {
    try {
      await client.rpc(
        'set_order_payment_cod',
        params: <String, dynamic>{'p_order_id': orderId},
      );
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('not_authenticated')) {
        throw const AuthException('Sign in required.');
      }
      if (m.contains('order_not_found') || m.contains('forbidden')) {
        throw const ValidationException('Could not update this order.');
      }
      throw RepositoryException(e.message.trim().isNotEmpty ? e.message : e.toString());
    }
  }
}
