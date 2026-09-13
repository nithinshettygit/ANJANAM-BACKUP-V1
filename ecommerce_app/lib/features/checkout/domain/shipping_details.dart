/// Shipping address used at checkout (snapshot sent with place order).
class ShippingDetails {
  final String fullName;
  final String phone;
  final String addressLine;
  final String city;
  final String postalCode;
  final String? state;

  const ShippingDetails({
    required this.fullName,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.postalCode,
    this.state,
  });

  Map<String, dynamic> toRpcJson() => <String, dynamic>{
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'address_line': addressLine.trim(),
        'city': city.trim(),
        'postal_code': postalCode.trim(),
        if (state != null && state!.trim().isNotEmpty) 'state': state!.trim(),
      };

  static const String englishOnlyErrorMessage =
      'Please enter your address in English only. Use English letters (A-Z), numbers and common address symbols.';

  static bool isEnglishAddressText(String? raw) {
    if (raw == null || raw.isEmpty) return true;
    return RegExp(r'^[\x20-\x7E\r\n]*$').hasMatch(raw);
  }

  static String? validateEnglishAddressText(
    String? value, {
    bool required = true,
    int minLength = 1,
    String? requiredMessage,
  }) {
    final v = value ?? '';
    final trimmed = v.trim();
    if (required && trimmed.length < minLength) {
      return requiredMessage ?? 'Required';
    }
    if (!isEnglishAddressText(v)) {
      return englishOnlyErrorMessage;
    }
    return null;
  }

  static bool isValidIndianPhone(String raw) {
    final d = raw.replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^\d{10}$').hasMatch(d);
  }

  static bool isValidIndianPostal(String raw) {
    final d = raw.trim();
    return RegExp(r'^\d{6}$').hasMatch(d);
  }

  /// Client-side validation before RPC.
  String? validationError() {
    if (fullName.trim().length < 2) return 'Please enter your full name.';
    if (!isEnglishAddressText(fullName)) return englishOnlyErrorMessage;
    if (!isValidIndianPhone(phone))
      return 'Enter a valid 10-digit mobile number.';
    if (addressLine.trim().length < 3)
      return 'Please enter a complete address.';
    if (!isEnglishAddressText(addressLine)) return englishOnlyErrorMessage;
    if (city.trim().length < 2) return 'Please enter your city.';
    if (!isEnglishAddressText(city)) return englishOnlyErrorMessage;
    if (state != null && !isEnglishAddressText(state)) return englishOnlyErrorMessage;
    if (!isValidIndianPostal(postalCode))
      return 'Enter a valid 6-digit PIN code.';
    return null;
  }
}
