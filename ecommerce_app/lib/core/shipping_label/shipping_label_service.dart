import 'dart:typed_data';

import 'package:ecommerce_app/admin/services/admin_service.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_address_formatter.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_data.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_generator.dart';
import 'package:ecommerce_app/core/document_settings/document_settings.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_payment.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps admin order rows to label payloads and generates PDF bytes.
class ShippingLabelService {
  ShippingLabelService({ShippingLabelGenerator? generator})
      : _generator = generator ?? ShippingLabelGenerator();

  final ShippingLabelGenerator _generator;

  static const List<String> defaultFromAddressLines = [
    'Anjanam',
    'Anjanam Warehouse',
    'MUGU, Kasaragod',
    'Kerala, India 671321',
    '+91 81291 07108',
  ];

  /// Builds label data from loaded admin order details.
  /// Throws [ShippingLabelException] when the order has no usable ship-to info.
  ShippingLabelData buildFromAdminOrder(AdminOrderDetails details) {
    return _buildFromAdminOrder(details, null);
  }

  ShippingLabelData _buildFromAdminOrder(
    AdminOrderDetails details,
    DocumentSettings? settings,
  ) {
    final order = details.order;
    final structured = _hasStructuredShipping(details);

    String? addressLine;
    if (structured) {
      addressLine = details.shippingAddressLine?.trim();
      if (addressLine != null && addressLine.isEmpty) addressLine = null;
    }

    final legacyAddress = structured ? '' : details.shippingAddress.trim();

    final customerName = ShippingLabelAddressFormatter.formatCustomerName(
      fullName: details.invoiceName ?? details.shippingFullName,
      fallbackCustomerName: order.customerName,
    );

    final phone =
        ShippingLabelAddressFormatter.formatPhone(details.shippingPhone) ??
            _missing;

    final shipToLines = ShippingLabelAddressFormatter.formatShipToLines(
      fullName: details.shippingFullName,
      phone: details.shippingPhone,
      addressLine: details.invoiceAddressLine ?? addressLine,
      city: details.invoiceCity ?? details.shippingCity,
      state: details.invoiceState ?? details.shippingState,
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
      fromAddressLines: settings?.labelFromAddressLines.isNotEmpty == true
          ? settings!.labelFromAddressLines
          : defaultFromAddressLines,
      codAmount: _codAmountIfApplicable(details),
      carrierName: _firstNonBlank(
        details.shippingProvider,
        details.courierName,
        settings?.labelCarrierName,
      ),
      carrierReference: _firstNonBlank(
        details.awbCode,
        details.trackingNumber,
        details.shipmentId,
      ),
      trackingUrl: details.trackingUrl,
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
    _validateRecipient(details, data, structured: structured);

    return data;
  }

  Future<Uint8List> generatePdf(ShippingLabelData data) {
    return _generator.generateLabelPdf(data);
  }

  Future<Uint8List> generatePdfForAdminOrder(AdminOrderDetails details) async {
    final settings =
        await DocumentSettingsService(Supabase.instance.client).fetch();
    final data = _buildFromAdminOrder(details, settings);
    return generatePdf(data);
  }

  /// Generates one PDF per order (for future bulk printing workflows).
  Future<List<Uint8List>> generatePdfBatch(
      List<ShippingLabelData> labels) async {
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

  static void _validateRecipient(
    AdminOrderDetails details,
    ShippingLabelData data, {
    required bool structured,
  }) {
    if (data.customerName == _missing || data.customerName.trim().isEmpty) {
      throw const ShippingLabelException(
        'Recipient name is missing for this order.',
      );
    }

    final hasAddress = data.shipToLines.any(
      (line) => line.trim().isNotEmpty && line.trim() != _missing,
    );
    if (!hasAddress) {
      throw const ShippingLabelException(
        'Recipient address is missing for this order.',
      );
    }

    final postalCode = structured
        ? details.shippingPostalCode?.trim()
        : _extractIndianPostalCode(details.shippingAddress);
    if (postalCode == null || !RegExp(r'^\d{6}$').hasMatch(postalCode)) {
      throw const ShippingLabelException(
        'A valid six-digit recipient PIN code is required for the shipping label.',
      );
    }
  }

  static String? _extractIndianPostalCode(String value) {
    final match = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(value);
    return match?.group(0);
  }

  static String? _firstNonBlank(String? first,
      [String? second, String? third]) {
    for (final value in [first, second, third]) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static const String _missing = '—';
}
