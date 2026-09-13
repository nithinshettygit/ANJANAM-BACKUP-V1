import 'dart:html' as html;
import 'dart:typed_data';

/// Web: `Printing.layoutPdf` is not implemented — open the PDF in a new tab.
Future<void> openInvoicePreview(Uint8List pdfBytes,
    {required String name}) async {
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future<void>.delayed(const Duration(minutes: 1), () {
    html.Url.revokeObjectUrl(url);
  });
}

Future<void> downloadPdf(Uint8List pdfBytes, {required String name}) async {
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = '$name.pdf'
    ..style.display = 'none';

  try {
    html.document.body?.append(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    Future<void>.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
