/// Snapshot of shipping address stored on the order row (checkout).
class OrderShippingInfo {
  final String? fullName;
  final String? phone;
  final String? addressLine;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? invoiceName;
  final String? invoiceAddressLine;
  final String? invoiceCity;
  final String? invoiceState;

  const OrderShippingInfo({
    this.fullName,
    this.phone,
    this.addressLine,
    this.city,
    this.state,
    this.postalCode,
    this.invoiceName,
    this.invoiceAddressLine,
    this.invoiceCity,
    this.invoiceState,
  });

  String? get displayName => _prefer(invoiceName, fullName);
  String? get displayAddressLine => _prefer(invoiceAddressLine, addressLine);
  String? get displayCity => _prefer(invoiceCity, city);
  String? get displayState => _prefer(invoiceState, state);

  OrderShippingInfo copyWith({
    String? invoiceName,
    String? invoiceAddressLine,
    String? invoiceCity,
    String? invoiceState,
  }) {
    return OrderShippingInfo(
      fullName: fullName,
      phone: phone,
      addressLine: addressLine,
      city: city,
      state: state,
      postalCode: postalCode,
      invoiceName: invoiceName ?? this.invoiceName,
      invoiceAddressLine: invoiceAddressLine ?? this.invoiceAddressLine,
      invoiceCity: invoiceCity ?? this.invoiceCity,
      invoiceState: invoiceState ?? this.invoiceState,
    );
  }

  static String? _prefer(String? preferred, String? fallback) {
    final value = preferred?.trim();
    if (value != null && value.isNotEmpty) return value;
    return fallback;
  }

  bool get hasStructuredAddress =>
      (fullName != null && fullName!.trim().isNotEmpty) ||
      (phone != null && phone!.trim().isNotEmpty) ||
      (addressLine != null && addressLine!.trim().isNotEmpty) ||
      (city != null && city!.trim().isNotEmpty) ||
      (postalCode != null && postalCode!.trim().isNotEmpty);

  String get formattedMultiline {
    final buf = StringBuffer();
    if (fullName != null && fullName!.trim().isNotEmpty) {
      buf.writeln(fullName!.trim());
    }
    if (phone != null && phone!.trim().isNotEmpty) {
      buf.writeln('Phone: ${phone!.trim()}');
    }
    if (addressLine != null && addressLine!.trim().isNotEmpty) {
      buf.writeln(addressLine!.trim());
    }
    final cityLine = [
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (postalCode != null && postalCode!.trim().isNotEmpty) postalCode!.trim(),
    ].join(', ');
    if (cityLine.isNotEmpty) buf.writeln(cityLine);
    return buf.toString().trim();
  }
}
