import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile / desktop: print preview when the printing plugin is wired; otherwise
/// share the PDF (covers `MissingPluginException` on `printPdf` seen on some builds).
Future<void> openInvoicePreview(Uint8List pdfBytes, {required String name}) async {
  try {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: '$name.pdf',
    );
    return;
  } on MissingPluginException catch (e, st) {
    if (kDebugMode) {
      debugPrint('Invoice: layoutPdf missing plugin ($e), trying sharePdf');
      debugPrint('$st');
    }
  }

  try {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '$name.pdf',
    );
    return;
  } on MissingPluginException catch (e, st) {
    if (kDebugMode) {
      debugPrint('Invoice: sharePdf missing plugin ($e), using share_plus');
      debugPrint('$st');
    }
  }

  await _sharePdfWithSharePlus(pdfBytes, name);
}

Future<void> _sharePdfWithSharePlus(Uint8List pdfBytes, String name) async {
  final dir = await getTemporaryDirectory();
  final safe = name.replaceAll(RegExp(r'[^\w\-.]+'), '_');
  final path = '${dir.path}${Platform.pathSeparator}$safe.pdf';
  final file = File(path);
  await file.writeAsBytes(pdfBytes, flush: true);
  final xfile = XFile(
    path,
    mimeType: 'application/pdf',
    name: '$safe.pdf',
  );
  await Share.shareXFiles(
    [xfile],
    subject: 'Invoice',
    text: 'Order invoice',
  );
}
