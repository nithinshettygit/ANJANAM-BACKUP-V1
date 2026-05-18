import 'dart:typed_data';

import 'package:ecommerce_app/admin/services/admin_service.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_address_formatter.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_data.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_generator.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_payment.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';

/// Maps admin order rows to label payloads and generates PDF bytes.
class ShippingLabelService {
  ShippingLabelService({ShippingLabelGenerator? generator})
      : _generator = generator ?? ShippingLabelGenerator();

  final ShippingLabelGenerator _generator;

  static const List<String> defaultFromAddressLines = [
    'Anjanam',
    'Anjanam Warehouse',
    'Perne Village, Perne Post',
    'Bantwal Taluk, D.K.',
    'Karnataka, India 574325',
    '+91 81291 07108',
  ];

  /// Builds label data from loaded admin order details.
  /// Throws [ShippingLabelException] when the order has no usable ship-to info.
  ShippingLabelData buildFromAdminOrder(AdminOrderDetails details) {
    final order = details.order;
    final structured = _hasStructuredShipping(details);

    String? addressLine;
    if (structured) {
      addressLine = details.shippingAddressLine?.trim();
      if (addressLine != null && addressLine.isEmpty) addressLine = null;
    }

    final legacyAddress =
        structured ? '' : details.shippingAddress.trim();

    final customerName = ShippingLabelAddressFormatter.formatCustomerName(
      fullName: details.shippingFullName,
      fallbackCustomerName: order.customerName,
    );

    final phone = ShippingLabelAddressFormatter.formatPhone(details.shippingPhone) ??
        _missing;

    final shipToLines = ShippingLabelAddressFormatter.formatShipToLines(
      fullName: details.shippingFullName,
      phone: details.shippingPhone,
      addressLine: addressLine,
      city: details.shippingCity,
      state: details.shippingState,
      postalCode: details.shippingPostalCode,
      legacyAddress: legacyAddress,
      fallbackCustomerName: order.customerName,
    );

    final data = ShippingLabelData(
      orderId: order.id,
      orderIdDisplay: formatOrderIdDisplay(order.id),
      orderDate: order.createdAt,
      customerName: customerName,
      phone: phone,
      shipToLines: shipToLines,
      fromAddressLines: defaultFromAddressLines,
      codAmount: _codAmountIfApplicable(details),
      barcodeData: order.id,
      qrData: Uri(
        scheme: 'https',
        host: 'anjanam.store',
        pathSegments: ['order', order.id],
      ).toString(),
    );

    if (!data.hasShipTo) {
      throw const ShippingLabelException(
        'Shipping address is missing for this order.',
      );
    }

    return data;
  }

  Future<Uint8List> generatePdf(ShippingLabelData data) {
    return _generator.generateLabelPdf(data);
  }

  Future<Uint8List> generatePdfForAdminOrder(AdminOrderDetails details) async {
    final data = buildFromAdminOrder(details);
    return generatePdf(data);
  }

  /// Generates one PDF per order (for future bulk printing workflows).
  Future<List<Uint8List>> generatePdfBatch(List<ShippingLabelData> labels) async {
    final out = <Uint8List>[];
    for (final label in labels) {
      out.add(await _generator.generateLabelPdf(label));
    }
    return out;
  }

  static bool _hasStructuredShipping(AdminOrderDetails d) {
    return (d.shippingFullName != null && d.shippingFullName!.isNotEmpty) ||
        (d.shippingPhone != null && d.shippingPhone!.isNotEmpty) ||
        (d.shippingAddressLine != null && d.shippingAddressLine!.isNotEmpty) ||
        (d.shippingCity != null && d.shippingCity!.isNotEmpty) ||
        (d.shippingPostalCode != null && d.shippingPostalCode!.isNotEmpty) ||
        (d.shippingState != null && d.shippingState!.isNotEmpty);
  }

  static double? _codAmountIfApplicable(AdminOrderDetails details) {
    final method = orderPaymentMethodFromDb(details.paymentMethod);
    if (method != OrderPaymentMethod.cod) return null;
    final total = details.order.totalAmount;
    if (total <= 0) return null;
    return total;
  }

  static const String _missing = '—';
}
