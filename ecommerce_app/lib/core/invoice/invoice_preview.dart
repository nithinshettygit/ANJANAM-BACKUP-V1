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

/// Creates a browser popup in the same user-interaction that triggered the action,
/// then later attaches the generated PDF to it once the bytes are ready.
Future<Object?> prepareInvoicePreview({String name = 'invoice'}) async {
  return impl.preparePreview(name: name);
}

Future<void> finalizeInvoicePreview(
  Object? previewHandle,
  Uint8List pdfBytes, {
  String name = 'invoice',
}) async {
  await impl.finalizePreview(previewHandle, pdfBytes, name: name);
}

/// Downloads/previews PDF bytes using the platform's application-level preview & download flow.
Future<void> downloadInvoicePdf(
  Uint8List pdfBytes, {
  String name = 'invoice',
}) async {
  await previewInvoicePdf(pdfBytes, name: name);
}
