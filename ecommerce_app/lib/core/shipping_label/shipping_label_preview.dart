import 'dart:typed_data';

import 'package:ecommerce_app/core/invoice/invoice_preview.dart';

Future<Object?> prepareShippingLabelPreview({String name = 'shipping_label'}) async {
  return prepareInvoicePreview(name: name);
}

Future<void> finalizeShippingLabelPreview(
  Object? previewHandle,
  Uint8List pdfBytes, {
  String name = 'shipping_label',
}) async {
  await finalizeInvoicePreview(previewHandle, pdfBytes, name: name);
}

/// Opens or downloads a shipping-label PDF (same platform behavior as invoices).
Future<void> previewShippingLabelPdf(
  Uint8List pdfBytes, {
  String name = 'shipping_label',
}) async {
  await previewInvoicePdf(pdfBytes, name: name);
}
