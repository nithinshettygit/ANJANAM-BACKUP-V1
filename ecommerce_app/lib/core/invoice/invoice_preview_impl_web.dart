import 'dart:html' as html;
import 'dart:typed_data';

/// Web: `Printing.layoutPdf` is not implemented — open the PDF in a new tab.
Future<void> openInvoicePreview(Uint8List pdfBytes, {required String name}) async {
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future<void>.delayed(const Duration(seconds: 2), () {
    html.Url.revokeObjectUrl(url);
  });
}
