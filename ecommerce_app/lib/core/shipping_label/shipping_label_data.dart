/// Normalized payload for a single 4×6 shipping label (reusable for bulk printing).
class ShippingLabelData {
  final String orderId;
  final String orderIdDisplay;
  final DateTime orderDate;
  final String customerName;
  final String phone;
  /// Multiline ship-to address (excludes phone).
  final List<String> shipToLines;
  final List<String> fromAddressLines;
  /// When set, shown as COD collect amount on the label.
  final double? codAmount;
  final String barcodeData;
  final String qrData;

  const ShippingLabelData({
    required this.orderId,
    required this.orderIdDisplay,
    required this.orderDate,
    required this.customerName,
    required this.phone,
    required this.shipToLines,
    required this.fromAddressLines,
    this.codAmount,
    required this.barcodeData,
    required this.qrData,
  });

  bool get hasShipTo =>
      customerName.trim().isNotEmpty ||
      phone.trim().isNotEmpty ||
      shipToLines.any((l) => l.trim().isNotEmpty);
}

class ShippingLabelException implements Exception {
  final String message;

  const ShippingLabelException(this.message);

  @override
  String toString() => message;
}
