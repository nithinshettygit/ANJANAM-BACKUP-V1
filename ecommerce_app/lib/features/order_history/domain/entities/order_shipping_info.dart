/// Snapshot of shipping address stored on the order row (checkout).
class OrderShippingInfo {
  final String? fullName;
  final String? phone;
  final String? addressLine;
  final String? city;
  final String? postalCode;

  const OrderShippingInfo({
    this.fullName,
    this.phone,
    this.addressLine,
    this.city,
    this.postalCode,
  });

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
