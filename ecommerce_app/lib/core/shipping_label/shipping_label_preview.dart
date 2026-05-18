import 'dart:typed_data';

import 'package:ecommerce_app/core/invoice/invoice_preview.dart';

/// Opens or downloads a shipping-label PDF (same platform behavior as invoices).
Future<void> previewShippingLabelPdf(
  Uint8List pdfBytes, {
  String name = 'shipping_label',
}) async {
  await previewInvoicePdf(pdfBytes, name: name);
}
