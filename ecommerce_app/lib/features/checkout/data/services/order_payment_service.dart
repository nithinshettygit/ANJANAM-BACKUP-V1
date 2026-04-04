import 'dart:developer' as developer;

import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

/// Persists Razorpay outcome via [update_order_payment_status] RPC (RLS-safe).
class OrderPaymentService extends SupabaseServiceBase {
  OrderPaymentService(super.client);

  static bool _functionPathNotFound(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('404') ||
        t.contains('not found') ||
        t.contains('requested function was not found');
  }

  /// Creates a Razorpay Order (`order_...`) via Edge Function, or returns `null` if the
  /// function is not deployed (HTTP 404) so checkout can fall back to key+amount flow.
  ///
  /// Use the same Razorpay Key Id in the app as `RAZORPAY_KEY_ID` in function secrets.
  Future<String?> tryCreateRazorpayServerOrder({required String orderId}) async {
    try {
      await client.auth.refreshSession();
    } catch (_) {}
    final accessToken = client.auth.currentSession?.accessToken.trim() ?? '';
    if (accessToken.isEmpty) {
      throw const AuthException('Sign in required.');
    }
    try {
      final res = await client.functions.invoke(
        'create-razorpay-order',
        headers: <String, String>{
          'Authorization': 'Bearer $accessToken',
        },
        body: <String, dynamic>{'order_id': orderId},
      );
      if (res.status == 404) {
        developer.log(
          'Edge Function create-razorpay-order returned 404 (not deployed?). '
          'Using Razorpay checkout without server order_id.',
          name: 'OrderPaymentService',
        );
        return null;
      }
      final data = res.data;
      if (res.status < 200 || res.status >= 300) {
        final err = (data is Map ? data['error']?.toString() : null) ?? 'invoke_failed';
        final detail = (data is Map ? data['detail']?.toString() : null) ?? '';
        throw RepositoryException(
          detail.isEmpty ? 'Could not start payment ($err).' : 'Could not start payment ($err): $detail',
        );
      }
      if (data is Map) {
        final id = data['razorpay_order_id']?.toString().trim();
        if (id != null && id.isNotEmpty) return id;
      }
      throw const RepositoryException('Could not start payment (missing order id).');
    } on AuthException {
      rethrow;
    } catch (e) {
      if (e is RepositoryException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('status 401') || msg.contains('unauthorized')) {
        throw const RepositoryException(
          'Could not start payment (auth). Please sign in again and retry.',
        );
      }
      if (_functionPathNotFound(e)) {
        developer.log(
          'create-razorpay-order unavailable ($e). Opening Razorpay without server order_id.',
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

  /// Test-mode safety: ensure Razorpay payment is captured before marking paid.
  Future<void> ensureTestPaymentCaptured({
    required String orderId,
    required String razorpayPaymentId,
    required bool isTestMode,
  }) async {
    if (!isTestMode) return;
    final pid = razorpayPaymentId.trim();
    if (pid.isEmpty) {
      throw const ValidationException('Missing payment reference.');
    }
    // Ensure JWT used for function auth is fresh.
    // Some browsers/devices may have an expired access token at the moment
    // of Razorpay success callback.
    try {
      await client.auth.refreshSession();
    } catch (_) {
      // Best-effort refresh; invoke will still work if token is valid.
    }
    final accessToken = client.auth.currentSession?.accessToken.trim() ?? '';
    if (accessToken.isEmpty) {
      throw const AuthException('Sign in required.');
    }
    try {
      final res = await client.functions.invoke(
        'capture-razorpay-payment',
        headers: <String, String>{
          'Authorization': 'Bearer $accessToken',
        },
        body: <String, dynamic>{
          'order_id': orderId,
          'razorpay_payment_id': pid,
        },
      );
      final data = res.data;
      if (res.status < 200 || res.status >= 300) {
        final err = (data is Map ? data['error']?.toString() : null) ?? null;
        final detail = (data is Map ? data['detail']?.toString() : null) ?? null;
        throw RepositoryException(
          err == null
              ? 'Could not verify payment capture (status ${res.status}).'
              : 'Payment capture verification failed: $err'
                  '${detail == null || detail.isEmpty ? '' : ' ($detail)'}.',
        );
      }
      if (data is Map) {
        final ok = data['ok'] == true;
        if (!ok) {
          final err = data['error']?.toString();
          throw RepositoryException(
            err == null || err.isEmpty
                ? 'Could not verify payment capture.'
                : err,
          );
        }
      }
    } on PostgrestException catch (e) {
      throw RepositoryException(e.message.trim().isEmpty ? e.toString() : e.message);
    } catch (e) {
      final msg = e.toString();
      final lower = msg.toLowerCase();
      if (lower.contains('missing_auth')) {
        throw const RepositoryException(
          'Payment authorized but capture verification failed: missing auth token. Please sign in again and retry.',
        );
      }
      if (lower.contains('invalid_jwt_format')) {
        throw const RepositoryException(
          'Payment authorized but capture verification failed: invalid auth token format. Please sign in again and retry.',
        );
      }
      if (lower.contains('status 401') || lower.contains('unauthorized')) {
        throw const RepositoryException(
          'Payment succeeded but capture verification failed (auth). Please sign in again and retry.',
        );
      }
      if (msg.toLowerCase().contains('payment_capture_failed')) {
        throw const RepositoryException(
          'Payment authorized but capture failed. Please retry or contact support.',
        );
      }
      if (msg.toLowerCase().contains('razorpay_order_mismatch')) {
        throw const RepositoryException(
          'Payment does not match this checkout session. Do not change payment apps mid-flow; place a new order if needed.',
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
