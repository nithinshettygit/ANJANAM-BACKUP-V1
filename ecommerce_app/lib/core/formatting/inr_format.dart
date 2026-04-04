import 'package:ecommerce_app/core/constants/app_currency.dart';

/// Display amounts in Indian Rupees (₹), with thousands separators.
String formatInrAmount(double amount) {
  final negative = amount < 0;
  final absolute = amount.abs();
  final whole = absolute.floor();
  final fraction = ((absolute - whole) * 100).round().toString().padLeft(2, '0');
  final grouped = _groupThousands(whole);
  final prefix = negative ? '-' : '';
  return '$prefix₹ $grouped.$fraction';
}

/// Same grouping as [formatInrAmount] but ASCII-only (`Rs.`) for PDF engines
/// that only embed Helvetica (no ₹ glyph).
String formatInrAmountPdfSafe(double amount) {
  final negative = amount < 0;
  final absolute = amount.abs();
  final whole = absolute.floor();
  final fraction = ((absolute - whole) * 100).round().toString().padLeft(2, '0');
  final grouped = _groupThousands(whole);
  final prefix = negative ? '-' : '';
  return '$prefix Rs. $grouped.$fraction';
}

/// Like [formatInrAmount] but omits `.00` when the amount is a whole rupee value.
String formatInrCompact(double amount) {
  final negative = amount < 0;
  final absolute = amount.abs();
  final whole = absolute.floor();
  final fracHundredths = ((absolute - whole) * 100).round().clamp(0, 99);
  final grouped = _groupThousands(whole);
  final prefix = negative ? '-' : '';
  if (fracHundredths == 0) {
    return '$prefix₹ $grouped';
  }
  return '$prefix₹ $grouped.${fracHundredths.toString().padLeft(2, '0')}';
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final reverseIndex = digits.length - i;
    buffer.write(digits[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

/// Use when parsing JSON may omit currency; always normalize to INR for this app.
String currencyOrInr(Object? raw) {
  final s = raw?.toString().trim().toUpperCase() ?? '';
  if (s.isEmpty || s == 'USD') return kAppCurrencyCode;
  return s;
}
