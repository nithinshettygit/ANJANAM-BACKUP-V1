import 'dart:developer' as developer;

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Wraps [Razorpay] checkout: init, open, success / error / external wallet.
///
/// Use only the **Key Id** (`rzp_live_...`). Never ship the Razorpay secret.
///
/// IO / mobile only — web uses [razorpay_service_web.dart].
class RazorpayService {
  RazorpayService({required String keyId}) : _keyId = keyId.trim();

  final String _keyId;
  final Razorpay _razorpay = Razorpay();

  /// Saffron / gold accent for checkout chrome (Razorpay theme color).
  static const String themeColorHex = '#C17F24';

  void dispose() {
    _razorpay.clear();
  }

  /// Opens standard Razorpay checkout (card, UPI, netbanking, wallets, etc.).
  ///
  /// When [razorpayOrderId] is set (from Razorpay Orders API), checkout is tied to
  /// that `order_*` id so payments show under Transactions in the Razorpay dashboard.
  void openCheckout({
    required int amountPaise,
    required String customerName,
    required String customerEmail,
    required String customerContact,
    /// From server: `order_...` (omit for legacy client-only amount checkout).
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

    _razorpay.clear();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      final id = response.paymentId?.trim() ?? '';
      if (id.isEmpty) {
        onPaymentError?.call('Payment succeeded but no payment id was returned. Please contact support.');
        return;
      }
      final oid = response.orderId?.trim();
      final sig = response.signature?.trim();
      onPaymentSuccess?.call(
        id,
        oid != null && oid.isNotEmpty ? oid : null,
        sig != null && sig.isNotEmpty ? sig : null,
      );
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      onPaymentError?.call(_friendlyPaymentError(response));
    });

    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      final name = response.walletName?.trim() ?? 'unknown';
      developer.log(
        'Razorpay external wallet selected: $name',
        name: 'RazorpayService',
      );
      onExternalWallet?.call(name);
    });

    final oid = razorpayOrderId?.trim() ?? '';
    final options = <String, dynamic>{
      'key': _keyId,
      'amount': amountPaise,
      'name': 'ANJANAM',
      'description': 'Spiritual Products Order',
      'currency': 'INR',
      if (oid.isNotEmpty) 'order_id': oid,
      'prefill': <String, dynamic>{
        'name': customerName.trim().isEmpty ? 'Customer' : customerName.trim(),
        if (customerEmail.trim().isNotEmpty) 'email': customerEmail.trim(),
        if (customerContact.trim().isNotEmpty) 'contact': customerContact.trim(),
      },
      'theme': <String, dynamic>{
        'color': themeColorHex,
      },
    };

    try {
      _razorpay.open(options);
    } catch (e, st) {
      developer.log(
        'Razorpay open failed: $e',
        name: 'RazorpayService',
        error: e,
        stackTrace: st,
      );
      onPaymentError?.call('Could not start payment. Please try again.');
    }
  }

  /// Same as [openCheckout]; exists so checkout can `await` before polling on web.
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
    openCheckout(
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

  static String _friendlyPaymentError(PaymentFailureResponse response) {
    final code = response.code;
    final raw = response.message?.trim();
    if (code == Razorpay.PAYMENT_CANCELLED) {
      return 'Payment was cancelled.';
    }
    if (code == Razorpay.NETWORK_ERROR) {
      return 'Network error. Check your connection and try again.';
    }
    if (code == Razorpay.TLS_ERROR) {
      return 'Secure connection error. Try again or update your device.';
    }
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return 'Payment could not be completed.';
  }
}
