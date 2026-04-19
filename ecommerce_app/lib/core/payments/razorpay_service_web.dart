// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
// `dart:html` / `dart:js_util` are web-only libraries (valid for `flutter build web` / `flutter run -d chrome`).
import 'dart:html' as html; // ignore: uri_does_not_exist
import 'dart:js_util' as js_util; // ignore: uri_does_not_exist

import 'package:flutter/foundation.dart';

/// Razorpay [Checkout.js](https://razorpay.com/docs/payments/payment-gateway/web-integration/standard/integration-steps)
/// for Flutter Web. Mobile uses `razorpay_flutter` via [razorpay_service_io.dart].
class RazorpayService {
  RazorpayService({required String keyId}) : _keyId = keyId.trim();

  final String _keyId;
  bool _disposed = false;

  /// Saffron / gold accent for checkout chrome (Razorpay theme color).
  static const String themeColorHex = '#C17F24';

  static Future<void>? _scriptLoad;

  void dispose() {
    _disposed = true;
  }

  /// Ensures `https://checkout.razorpay.com/v1/checkout.js` is loaded (also in [web/index.html]).
  static Future<void> _ensureCheckoutScript() {
    if (js_util.hasProperty(html.window, 'Razorpay')) {
      return Future<void>.value();
    }
    _scriptLoad ??= () async {
      final completer = Completer<void>();
      final script = html.ScriptElement()
        ..async = true
        ..src = 'https://checkout.razorpay.com/v1/checkout.js';
      script.onError.listen((_) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Failed to load Razorpay checkout script.'),
          );
        }
      });
      script.onLoad.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      html.document.head!.append(script);
      return completer.future;
    }();
    return _scriptLoad!;
  }

  void openCheckout({
    required int amountPaise,
    required String customerName,
    required String customerEmail,
    required String customerContact,
    String? razorpayOrderId,
    void Function(String razorpayPaymentId, String? razorpayOrderId, String? razorpaySignature)?
        onPaymentSuccess,
    void Function(String message)? onPaymentError,
    void Function(String walletName)? onExternalWallet,
  }) {
    if (_keyId.isEmpty) {
      onPaymentError?.call(
        'Payments are not configured. Add your Razorpay Key Id at build time '
        '(--dart-define=RAZORPAY_KEY_ID=...).',
      );
      return;
    }

    if (amountPaise < 100) {
      onPaymentError?.call('Order total is too small to charge (minimum ₹1).');
      return;
    }

    _ensureCheckoutScript().then((_) {
      if (_disposed) return;
      _openCheckoutJs(
        amountPaise: amountPaise,
        customerName: customerName,
        customerEmail: customerEmail,
        customerContact: customerContact,
        razorpayOrderId: razorpayOrderId,
        onPaymentSuccess: onPaymentSuccess,
        onPaymentError: onPaymentError,
        onExternalWallet: onExternalWallet,
      );
    }).catchError((Object e, StackTrace st) {
      if (kDebugMode) {
        debugPrint('Razorpay script load failed: $e\n$st');
      }
      onPaymentError?.call(
        'Could not load payment checkout. Check your connection and try again.',
      );
    });
  }

  /// Awaits checkout.js, then opens the modal. Call this from Flutter Web checkout
  /// **before** starting payment-status polling so polling does not race the UI.
  Future<void> openCheckoutAfterScriptReady({
    required int amountPaise,
    required String customerName,
    required String customerEmail,
    required String customerContact,
    String? razorpayOrderId,
    void Function(String razorpayPaymentId, String? razorpayOrderId, String? razorpaySignature)?
        onPaymentSuccess,
    void Function(String message)? onPaymentError,
    void Function(String walletName)? onExternalWallet,
  }) async {
    if (_keyId.isEmpty) {
      onPaymentError?.call(
        'Payments are not configured. Add your Razorpay Key Id at build time '
        '(--dart-define=RAZORPAY_KEY_ID=...).',
      );
      return;
    }

    if (amountPaise < 100) {
      onPaymentError?.call('Order total is too small to charge (minimum ₹1).');
      return;
    }

    try {
      await _ensureCheckoutScript();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Razorpay script load failed: $e\n$st');
      }
      onPaymentError?.call(
        'Could not load payment checkout. Check your connection and try again.',
      );
      return;
    }
    if (_disposed) return;
    _openCheckoutJs(
      amountPaise: amountPaise,
      customerName: customerName,
      customerEmail: customerEmail,
      customerContact: customerContact,
      razorpayOrderId: razorpayOrderId,
      onPaymentSuccess: onPaymentSuccess,
      onPaymentError: onPaymentError,
      onExternalWallet: onExternalWallet,
    );
  }

  void _openCheckoutJs({
    required int amountPaise,
    required String customerName,
    required String customerEmail,
    required String customerContact,
    String? razorpayOrderId,
    void Function(String razorpayPaymentId, String? razorpayOrderId, String? razorpaySignature)?
        onPaymentSuccess,
    void Function(String message)? onPaymentError,
    void Function(String walletName)? onExternalWallet,
  }) {
    final Razorpay = js_util.getProperty(html.window, 'Razorpay');
    if (Razorpay == null) {
      onPaymentError?.call('Razorpay checkout is not available in this browser.');
      return;
    }

    final oid = razorpayOrderId?.trim() ?? '';
    var completed = false;

    void completeError(String message) {
      if (completed) return;
      completed = true;
      onPaymentError?.call(message);
    }

    void completeSuccess(String paymentId, String? orderId, String? signature) {
      if (completed) return;
      completed = true;
      onPaymentSuccess?.call(paymentId, orderId, signature);
    }

    final handler = js_util.allowInterop((dynamic resp) {
      final paymentId =
          js_util.getProperty(resp, 'razorpay_payment_id')?.toString().trim() ?? '';
      if (paymentId.isEmpty) {
        completeError(
          'Payment succeeded but no payment id was returned. Please contact support.',
        );
        return;
      }
      final orderIdRaw = js_util.getProperty(resp, 'razorpay_order_id');
      final o = orderIdRaw?.toString().trim();
      final sigRaw = js_util.getProperty(resp, 'razorpay_signature');
      final s = sigRaw?.toString().trim();
      completeSuccess(
        paymentId,
        o != null && o.isNotEmpty ? o : null,
        s != null && s.isNotEmpty ? s : null,
      );
    });

    final ondismiss = js_util.allowInterop((dynamic _) {
      if (!completed) {
        completeError('Payment was cancelled.');
      }
    });

    final paymentFailed = js_util.allowInterop((dynamic resp) {
      final err = js_util.getProperty(resp, 'error');
      var msg = 'Payment could not be completed.';
      if (err != null) {
        final desc = js_util.getProperty(err, 'description')?.toString().trim();
        if (desc != null && desc.isNotEmpty) msg = desc;
      }
      completeError(msg);
    });

    final prefill = <String, dynamic>{
      'name': customerName.trim().isEmpty ? 'Customer' : customerName.trim(),
      if (customerEmail.trim().isNotEmpty) 'email': customerEmail.trim(),
      if (customerContact.trim().isNotEmpty) 'contact': customerContact.trim(),
    };

    final options = <String, dynamic>{
      'key': _keyId,
      'name': 'ANJANAM',
      'description': 'Spiritual Products Order',
      'currency': 'INR',
      'amount': amountPaise,
      if (oid.isNotEmpty) 'order_id': oid,
      'prefill': prefill,
      'theme': <String, dynamic>{'color': themeColorHex},
      'handler': handler,
      'modal': <String, dynamic>{'ondismiss': ondismiss},
    };

    try {
      final jsOptions = js_util.jsify(options);
      final rzp = js_util.callConstructor(Razorpay, [jsOptions]);
      js_util.callMethod(rzp, 'on', ['payment.failed', paymentFailed]);
      js_util.callMethod(rzp, 'open', []);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Razorpay open failed: $e\n$st');
      }
      onPaymentError?.call('Could not start payment. Please try again.');
    }
  }
}
