import 'package:flutter/foundation.dart';

/// Razorpay mobile SDK is not linked on web; checkout is disabled here.
///
/// Storefront checkout paths already gate Razorpay on `kIsWeb`.
class RazorpayService {
  RazorpayService({required String keyId}) : _keyId = keyId.trim();

  final String _keyId;

  static const String themeColorHex = '#C17F24';

  void dispose() {}

  void openCheckout({
    required int amountPaise,
    required String customerName,
    required String customerEmail,
    required String customerContact,
    String? razorpayOrderId,
    void Function(String razorpayPaymentId, String? razorpayOrderId)? onPaymentSuccess,
    void Function(String message)? onPaymentError,
    void Function(String walletName)? onExternalWallet,
  }) {
    if (kDebugMode) {
      debugPrint(
        'Razorpay web stub: amount=$amountPaise '
        'customer=$customerName email=$customerEmail contact=$customerContact '
        'order=$razorpayOrderId callbacks=${onPaymentSuccess != null}|'
        '${onPaymentError != null}|${onExternalWallet != null}',
      );
    }
    if (_keyId.isEmpty) {
      onPaymentError?.call(
        'Payments are not configured. Add your test Key Id at build time '
        '(--dart-define=RAZORPAY_TEST_KEY=...).',
      );
      return;
    }
    onPaymentError?.call(
      'Card and UPI checkout runs in the Android or iOS app. '
      'This browser build does not open Razorpay.',
    );
  }
}
