import 'dart:typed_data';

import 'package:ecommerce_app/core/formatting/inr_format.dart' show formatInrAmountPdfSafe;
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_shipping_info.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
export 'invoice_preview.dart';

/// Builds a single-page invoice PDF for an [Order] and its line items.
class InvoiceGenerator {
  InvoiceGenerator();

  /// Generates PDF bytes. Pass [shipping] when available so the bill-to block is complete.
  Future<Uint8List> generateInvoicePdf(
    Order order,
    List<OrderItem> items, {
    OrderShippingInfo? shipping,
  }) async {
    final doc = pw.Document();
    final theme = await _buildInvoicePdfTheme();
    final logo = await _loadInvoiceLogo();
    // Use shared formatter (no intl locale init; DateFormat('…', 'en_IN') throws otherwise).
    final dateStr = formatOrderDetailsDateTime(order.createdAt);
    final invoiceNo = formatOrderIdDisplay(order.id);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (context) => [
          _header(invoiceNo, order.id, dateStr, logo: logo),
          pw.SizedBox(height: 20),
          _sectionTitle('CUSTOMER DETAILS'),
          _customerBlock(shipping),
          pw.SizedBox(height: 16),
          _sectionTitle('ITEMS'),
          _itemsTable(items),
          pw.SizedBox(height: 16),
          _sectionTitle('ORDER SUMMARY'),
          _summaryRows(order),
          pw.SizedBox(height: 16),
          _sectionTitle('PAYMENT INFORMATION'),
          _paymentBlock(order),
          pw.SizedBox(height: 28),
          _footer(),
        ],
      ),
    );

    return doc.save();
  }

  Future<pw.MemoryImage?> _loadInvoiceLogo() async {
    try {
      final bytes = await rootBundle.load('assets/branding/app_icon.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Load Unicode-capable fonts so invoice text renders for Kannada/Hindi/etc.
  /// Falls back to default PDF fonts if font download/loading fails.
  Future<pw.ThemeData?> _buildInvoicePdfTheme() async {
    try {
      final base = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      final italic = await PdfGoogleFonts.notoSansItalic();
      final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();
      final devanagari = await PdfGoogleFonts.notoSansDevanagariRegular();
      final devanagariBold = await PdfGoogleFonts.notoSansDevanagariBold();
      final kannada = await PdfGoogleFonts.notoSansKannadaRegular();
      final kannadaBold = await PdfGoogleFonts.notoSansKannadaBold();

      return pw.ThemeData.withFont(
        base: base,
        bold: bold,
        italic: italic,
        boldItalic: boldItalic,
        fontFallback: [
          devanagari,
          devanagariBold,
          kannada,
          kannadaBold,
        ],
      );
    } catch (_) {
      return null;
    }
  }

  pw.Widget _header(
    String invoiceShort,
    String orderId,
    String orderDate, {
    pw.MemoryImage? logo,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 52,
                height: 52,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColors.teal200, width: 0.7),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              )
            else
              pw.Container(
                width: 52,
                height: 52,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal50,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  'A',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal800,
                  ),
                ),
              ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'ANJANAM',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Tax Invoice',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.teal700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.teal200, width: 0.6),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Invoice #: INV-$invoiceShort',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Order ID', style: _labelStyle()),
                pw.Text(orderId, style: _valueStyle()),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Order Date', style: _labelStyle()),
                pw.Text(orderDate, style: _valueStyle()),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.teal900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  pw.Widget _customerBlock(OrderShippingInfo? s) {
    final name = _trimOrDash(s?.fullName);
    final phone = _trimOrDash(s?.phone);
    final addr = _trimOrDash(s?.addressLine);
    final city = _trimOrDash(s?.city);
    final pin = _trimOrDash(s?.postalCode);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kvLine('Customer Name', name),
        _kvLine('Phone', phone),
        _kvLine('Shipping Address', addr),
        _kvLine('City', city),
        _kvLine('Postal Code', pin),
      ],
    );
  }

  pw.Widget _itemsTable(List<OrderItem> items) {
    final data = items
        .map(
          (i) => [
            i.title,
            '${i.quantity}',
            _money(i.unitPrice),
            _money(i.lineTotal),
          ],
        )
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: const [
        'Product Name',
        'Qty',
        'Unit Price',
        'Total',
      ],
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
      cellHeight: 28,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      border: null,
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  pw.Widget _summaryRows(Order order) {
    final delivery = order.deliveryFee ?? 0;
    return pw.Column(
      children: [
        _summaryLine('Subtotal', formatInrAmountPdfSafe(order.subtotal)),
        _summaryLine(
          'Delivery Fee',
          delivery <= 0 ? 'FREE' : formatInrAmountPdfSafe(delivery),
        ),
        pw.Divider(thickness: 0.5),
        _summaryLine('Total Amount', formatInrAmountPdfSafe(order.grandTotal), bold: true),
      ],
    );
  }

  pw.Widget _paymentBlock(Order order) {
    final isCod = order.paymentMethod == OrderPaymentMethod.cod;
    final method = isCod ? 'Cash on Delivery' : order.paymentMethod.displayLabel;
    final status = isCod && order.paymentStatus == OrderPaymentStatus.pending
        ? 'Pending Payment'
        : order.paymentStatus.displayLabel;
    final rz = order.razorpayPaymentId?.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kvLine('Payment Method', method),
        _kvLine('Payment Status', status),
        if (!isCod && rz != null && rz.isNotEmpty) _kvLine('Razorpay Payment ID', rz),
      ],
    );
  }

  pw.Widget _footer() {
    return pw.Center(
      child: pw.Text(
        'Thank you for shopping with ANJANAM',
        style: pw.TextStyle(
          fontSize: 10,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.grey700,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.TextStyle _labelStyle() =>
      const pw.TextStyle(fontSize: 8, color: PdfColors.grey700);

  static pw.TextStyle _valueStyle() =>
      pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.normal);

  static pw.Widget _kvLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: _labelStyle()),
          ),
          pw.Expanded(child: pw.Text(value, style: _valueStyle())),
        ],
      ),
    );
  }

  static pw.Widget _summaryLine(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 11 : 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static String _trimOrDash(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? '-' : t;
  }

  static String _money(double amount) => formatInrAmountPdfSafe(amount);
}
