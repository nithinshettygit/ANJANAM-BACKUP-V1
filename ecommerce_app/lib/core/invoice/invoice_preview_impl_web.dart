import 'dart:html' as html;
import 'dart:typed_data';

Future<Object?> preparePreview({required String name}) async {
  final popup = html.window.open('', '_blank', 'noopener,noreferrer');
  return popup;
}

Future<void> finalizePreview(
  Object? previewHandle,
  Uint8List pdfBytes, {
  required String name,
}) async {
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final popup = previewHandle is html.Window ? previewHandle : null;
  try {
    if (popup != null) {
      popup.location.href = url;
      return;
    }

    final anchor = html.AnchorElement(href: url)
      ..download = '$name.pdf'
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    Future<void>.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}

/// Web: `Printing.layoutPdf` is not implemented — open the PDF in a new tab.
Future<void> openInvoicePreview(Uint8List pdfBytes,
    {required String name}) async {
  await finalizePreview(null, pdfBytes, name: name);
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
