import 'dart:typed_data';

import 'package:ecommerce_app/core/formatting/inr_format.dart' show formatInrAmountPdfSafe;
import 'package:ecommerce_app/core/shipping_label/shipping_label_data.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Standard 4×6 in thermal shipping label (portrait).
class ShippingLabelGenerator {
  static final PdfPageFormat labelPageFormat = PdfPageFormat(
    4 * PdfPageFormat.inch,
    6 * PdfPageFormat.inch,
    marginAll: 6,
  );

  static const String _brandName = 'Anjanam';

  Future<Uint8List> generateLabelPdf(ShippingLabelData data) async {
    final doc = pw.Document();
    final theme = await _buildLabelPdfTheme();
    final logo = await _loadLogo();
    final orderDate = formatOrderDetailsDateTime(data.orderDate);

    doc.addPage(
      pw.Page(
        pageFormat: labelPageFormat,
        theme: theme,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _topHeader(logo: logo, data: data, orderDate: orderDate),
            pw.SizedBox(height: 4),
            _section(
              title: 'FROM',
              child: _addressLines(data.fromAddressLines, fontSize: 7),
            ),
            pw.SizedBox(height: 4),
            _section(
              title: 'SHIP TO',
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.customerName,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  _addressLines(data.shipToLines, fontSize: 8.5),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Phone: ${data.phone}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (data.codAmount != null) ...[
              pw.SizedBox(height: 4),
              _codBanner(data.codAmount!),
            ],
            pw.Spacer(),
            _codesFooter(data),
          ],
        ),
      ),
    );

    return doc.save();
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/branding/app_icon.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<pw.ThemeData?> _buildLabelPdfTheme() async {
    try {
      final base = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      final devanagari = await PdfGoogleFonts.notoSansDevanagariRegular();
      final kannada = await PdfGoogleFonts.notoSansKannadaRegular();
      return pw.ThemeData.withFont(
        base: base,
        bold: bold,
        fontFallback: [devanagari, kannada],
      );
    } catch (_) {
      return null;
    }
  }

  pw.Widget _topHeader({
    required pw.MemoryImage? logo,
    required ShippingLabelData data,
    required String orderDate,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null)
            pw.Container(
              width: 32,
              height: 32,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 32,
              height: 32,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.5),
              ),
              child: pw.Text(
                'A',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _brandName,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Order: ${data.orderIdDisplay}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Date: $orderDate', style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _section({required String title, required pw.Widget child}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 3),
          child,
        ],
      ),
    );
  }

  pw.Widget _addressLines(List<String> lines, {required double fontSize}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1.5),
            child: pw.Text(line, style: pw.TextStyle(fontSize: fontSize)),
          ),
      ],
    );
  }

  pw.Widget _codBanner(double amount) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.9),
      ),
      child: pw.Text(
        'COD: Collect ${formatInrAmountPdfSafe(amount)}',
        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _codesFooter(ShippingLabelData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.7),
      ),
      child: pw.Column(
        children: [
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: data.barcodeData,
              width: labelPageFormat.availableWidth * 0.92,
              height: 36,
              drawText: true,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: data.qrData,
                width: 52,
                height: 52,
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  data.orderIdDisplay,
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
