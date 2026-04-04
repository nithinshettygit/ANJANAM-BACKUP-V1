import 'dart:convert';
import 'dart:developer' as developer;

/// Structured checkout events for logs / log aggregation (e.g. filter by name
/// `checkout_telemetry`). Wire to Crashlytics or a backend later if needed.
///
/// Event names (requirements doc):
/// - [checkoutRpcFailed]
/// - [legacyCheckoutAttempt]
/// - [inventoryInsufficient]
/// - [inactiveProductOrderAttempt]
abstract final class CheckoutTelemetry {
  static const String logName = 'checkout_telemetry';

  static void _emit(String event, Map<String, Object?> data) {
    final payload = <String, Object?>{'event': event, ...data};
    developer.log(
      jsonEncode(payload),
      name: logName,
    );
  }

  /// RPC error, misconfiguration, or unexpected PostgREST failure.
  static void checkoutRpcFailed({
    required String reason,
    String? detail,
  }) {
    _emit('checkout_rpc_failed', {
      'reason': reason,
      if (detail != null && detail.isNotEmpty) 'detail': detail,
    });
  }

  /// Non-production (or explicitly allowed release) path using direct inserts.
  static void legacyCheckoutAttempt({required String reason}) {
    _emit('legacy_checkout_attempt', {'reason': reason});
  }

  static void inventoryInsufficient({String? hint}) {
    _emit('inventory_insufficient', {
      if (hint != null) 'hint': hint,
    });
  }

  static void inactiveProductOrderAttempt({String? hint}) {
    _emit('inactive_product_order_attempt', {
      if (hint != null) 'hint': hint,
    });
  }
}
