/// Shipping address used at checkout (snapshot sent with place order).
class ShippingDetails {
  final String fullName;
  final String phone;
  final String addressLine;
  final String city;
  final String postalCode;

  const ShippingDetails({
    required this.fullName,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.postalCode,
  });

  Map<String, dynamic> toRpcJson() => <String, dynamic>{
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'address_line': addressLine.trim(),
        'city': city.trim(),
        'postal_code': postalCode.trim(),
      };

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
    if (!isValidIndianPhone(phone)) return 'Enter a valid 10-digit mobile number.';
    if (addressLine.trim().length < 3) return 'Please enter a complete address.';
    if (city.trim().length < 2) return 'Please enter your city.';
    if (!isValidIndianPostal(postalCode)) return 'Enter a valid 6-digit PIN code.';
    return null;
  }
}
