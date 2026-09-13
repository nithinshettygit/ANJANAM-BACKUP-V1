import 'dart:typed_data';

import 'invoice_preview_impl_io.dart'
    if (dart.library.html) 'invoice_preview_impl_web.dart' as impl;

/// Opens or downloads the invoice PDF in a platform-appropriate way.
Future<void> previewInvoicePdf(
  Uint8List pdfBytes, {
  String name = 'invoice',
}) async {
  await impl.openInvoicePreview(pdfBytes, name: name);
}

/// Downloads/previews PDF bytes using the platform's application-level preview & download flow.
Future<void> downloadInvoicePdf(
  Uint8List pdfBytes, {
  String name = 'invoice',
}) async {
  await previewInvoicePdf(pdfBytes, name: name);
}
