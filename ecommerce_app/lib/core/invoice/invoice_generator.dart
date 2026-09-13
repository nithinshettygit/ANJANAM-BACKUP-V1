import 'dart:typed_data';

import 'package:ecommerce_app/core/formatting/inr_format.dart'
    show formatInrAmountPdfSafe;
import 'package:ecommerce_app/core/document_settings/document_settings.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_shipping_info.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

export 'invoice_preview.dart';

class InvoicePdfInput {
  final Order order;
  final List<OrderItem> items;
  final OrderShippingInfo? shipping;

  const InvoicePdfInput({
    required this.order,
    required this.items,
    this.shipping,
  });
}

/// Builds a single-page invoice PDF for an [Order] and its line items.
/// Keeps generation admin-only via existing call sites.
class InvoiceGenerator {
  InvoiceGenerator();

  static const String _brandName = 'Anjanam';
  static const String _brandTagline = 'Commercial invoice';
  static const int _maxInvoiceItemRows = 8;

  /// Generates PDF bytes. Pass [shipping] when available so the bill-to block is complete.
  Future<Uint8List> generateInvoicePdf(
    Order order,
    List<OrderItem> items, {
    OrderShippingInfo? shipping,
    DocumentSettings? settingsOverride,
  }) async {
    final doc = pw.Document();
    final settings = settingsOverride ??
        await DocumentSettingsService(Supabase.instance.client).fetch();
    final theme = await _buildInvoicePdfTheme();
    final logo = await _loadInvoiceLogo();

    _addInvoicePage(
      doc,
      order: order,
      items: items,
      shipping: shipping,
      settings: settings,
      theme: theme,
      logo: logo,
    );

    return doc.save();
  }

  /// Generates one invoice page per input in a single PDF document.
  Future<Uint8List> generateInvoicePdfBatch(
    List<InvoicePdfInput> inputs, {
    DocumentSettings? settingsOverride,
  }) async {
    final doc = pw.Document();
    final settings = settingsOverride ??
        await DocumentSettingsService(Supabase.instance.client).fetch();
    final theme = await _buildInvoicePdfTheme();
    final logo = await _loadInvoiceLogo();

    for (final input in inputs) {
      _addInvoicePage(
        doc,
        order: input.order,
        items: input.items,
        shipping: input.shipping,
        settings: settings,
        theme: theme,
        logo: logo,
      );
    }

    return doc.save();
  }

  void _addInvoicePage(
    pw.Document doc, {
    required Order order,
    required List<OrderItem> items,
    required OrderShippingInfo? shipping,
    required DocumentSettings settings,
    required pw.ThemeData? theme,
    required pw.MemoryImage? logo,
  }) {
    final orderDate = formatOrderDetailsDateTime(order.createdAt);
    final invoiceDate = formatOrderDetailsDateTime(DateTime.now());
    final invoiceNo = 'INV-${formatOrderIdDisplay(order.id)}';
    final shippingInfo = _shippingAddress(shipping);
    final paymentInfo = _paymentInfo(order);
    final orderUrl = Uri(
      scheme: 'https',
      host: 'anjanam.store',
      pathSegments: ['order', order.id],
    ).toString();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 20),
        theme: theme,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(logo: logo, settings: settings),
            pw.SizedBox(height: 8),
            _invoiceMeta(
              invoiceNo: invoiceNo,
              orderId: order.id,
              invoiceDate: invoiceDate,
              orderDate: orderDate,
            ),
            pw.SizedBox(height: 8),
            _addressBlocks(shippingInfo, settings),
            pw.SizedBox(height: 8),
            _sectionTitle('Products'),
            _itemsTable(items),
            pw.SizedBox(height: 8),
            _sectionTitle('Pricing Summary'),
            _summaryRows(order),
            pw.SizedBox(height: 6),
            pw.Text(
              'Tax is calculated from the product configuration captured at order time.',
              style:
                  const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            _sectionTitle('Payment Information'),
            _paymentBlock(paymentInfo),
            pw.SizedBox(height: 8),
            _sectionTitle('Order Verification'),
            _qrBlock(orderUrl),
            pw.Spacer(),
            _footer(),
          ],
        ),
      ),
    );
  }

  Future<pw.MemoryImage?> _loadInvoiceLogo() async {
    try {
      final bytes = await rootBundle.load('assets/branding/app_icon.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Load bundled Unicode-capable fonts so invoice text renders offline.
  Future<pw.ThemeData?> _buildInvoicePdfTheme() async {
    try {
      final base = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
      );
      final italic = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Italic.ttf'),
      );
      final boldItalic = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-BoldItalic.ttf'),
      );
      final kannada = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKannada-Regular.ttf'),
      );
      final kannadaBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKannada-Bold.ttf'),
      );
      final devanagari = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
      );
      final devanagariBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf'),
      );

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
      {pw.MemoryImage? logo, required DocumentSettings settings}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null)
            pw.Container(
              width: 48,
              height: 48,
              padding: const pw.EdgeInsets.all(3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.6),
              ),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 48,
              height: 48,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.6),
              ),
              child: pw.Text(
                'A',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  settings.sellerLegalName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(_brandTagline, style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 6),
                pw.Text('Phone: ${settings.sellerPhone}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Email: ${settings.sellerEmail}',
                    style: const pw.TextStyle(fontSize: 9)),
                for (final line in _addressLines(settings.sellerAddress))
                  pw.Text(line, style: const pw.TextStyle(fontSize: 8)),
                if (settings.sellerGstin != null)
                  pw.Text('GSTIN: ${settings.sellerGstin}',
                      style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.8),
            ),
            child: pw.Text(
              'INVOICE',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _invoiceMeta({
    required String invoiceNo,
    required String orderId,
    required String invoiceDate,
    required String orderDate,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kvLine('Invoice Number', invoiceNo),
                _kvLine('Order ID', orderId),
              ],
            ),
          ),
          pw.SizedBox(width: 18),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _kvLine('Invoice Date', invoiceDate),
                _kvLine('Order Date', orderDate),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  pw.Widget _addressBlocks(
      _ShippingAddress shipping, DocumentSettings settings) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _addressCard(
            title: 'Customer Details',
            lines: [
              ['Name', shipping.name],
              ['Phone', shipping.phone],
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _addressCard(
            title: 'Deliver To',
            lines: [
              ['Address', shipping.address],
              ['City', shipping.city],
              ['Pincode', shipping.pincode],
              ['State', shipping.state],
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _addressCard(
            title: 'Warehouse / Return Address',
            lines: [
              for (final line in settings.labelFromAddressLines) ['', line],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _addressCard({
    required String title,
    required List<List<String>> lines,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          for (final line in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: line[0].isEmpty
                  ? pw.Text(line[1], style: const pw.TextStyle(fontSize: 8.5))
                  : _kvLine(line[0], line[1]),
            ),
        ],
      ),
    );
  }

  pw.Widget _itemsTable(List<OrderItem> items) {
    final visibleItems = items.take(_maxInvoiceItemRows).toList();
    final overflowCount = items.length - visibleItems.length;
    final data = visibleItems
        .map(
          (i) => [
            i.title,
            '${i.quantity}',
            _money(i.unitPrice),
            i.hsnCode ?? '-',
            i.gstRate == null ? '-' : '${i.gstRate}%',
            _money(i.taxableValue ?? i.lineTotal),
            _money(i.lineTotal),
          ],
        )
        .toList();
    if (overflowCount > 0) {
      final hiddenQty = items
          .skip(_maxInvoiceItemRows)
          .fold<int>(0, (sum, i) => sum + i.quantity);
      final hiddenTotal = items
          .skip(_maxInvoiceItemRows)
          .fold<double>(0, (sum, i) => sum + i.lineTotal);
      data.add([
        '+ $overflowCount more item(s)',
        '$hiddenQty',
        '-',
        '-',
        '-',
        _money(hiddenTotal),
        _money(hiddenTotal),
      ]);
    }

    final headers = <String>[
      'Item Name',
      'Quantity',
      'Unit Price',
      'HSN',
      'GST',
      'Taxable Value',
      'Total',
    ];
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 18,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 8.2),
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.4),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  pw.Widget _summaryRows(Order order) {
    final subtotal = order.subtotal;
    const discount = 0.0;
    final shipping = order.deliveryFee ?? 0.0;
    final total = order.grandTotal;
    final taxableSubtotal = order.items.fold<double>(
        0, (sum, item) => sum + (item.taxableValue ?? item.lineTotal));
    final cgst = order.items
        .fold<double>(0, (sum, item) => sum + (item.cgstAmount ?? 0));
    final sgst = order.items
        .fold<double>(0, (sum, item) => sum + (item.sgstAmount ?? 0));
    final igst = order.items
        .fold<double>(0, (sum, item) => sum + (item.igstAmount ?? 0));
    final totalTax = cgst + sgst + igst;
    return pw.Row(
      children: [
        pw.Spacer(),
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.7),
          ),
          child: pw.Column(
            children: [
              _summaryLine(
                'Item Total',
                _money(subtotal),
              ),
              _summaryLine('Discount', _money(discount)),
              _summaryLine('Shipping Charges',
                  shipping <= 0 ? 'FREE' : _money(shipping)),
              _summaryLine('Taxable Value', _money(taxableSubtotal)),
              if (cgst > 0) _summaryLine('CGST', _money(cgst)),
              if (sgst > 0) _summaryLine('SGST', _money(sgst)),
              if (igst > 0) _summaryLine('IGST', _money(igst)),
              if (totalTax > 0) _summaryLine('Total Tax', _money(totalTax)),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              _summaryLine('Final Total', _money(total), bold: true),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _paymentBlock(_PaymentInfo payment) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _kvLine('Payment Method', payment.method),
          _kvLine('Payment Status', payment.status),
          if (payment.reference != null)
            _kvLine('Reference', payment.reference!),
        ],
      ),
    );
  }

  pw.Widget _qrBlock(String orderUrl) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: orderUrl,
            width: 78,
            height: 78,
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Scan to open order',
                  style:
                      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                ),
                pw.SizedBox(height: 4),
                pw.Text(orderUrl, style: const pw.TextStyle(fontSize: 7.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.7)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'This is a computer-generated invoice.',
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Generated from the order record.',
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Thank you - $_brandName',
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.TextStyle _labelStyle() =>
      const pw.TextStyle(fontSize: 8.8, color: PdfColors.grey800);

  static pw.TextStyle _valueStyle() => const pw.TextStyle(fontSize: 8.8);

  static pw.Widget _kvLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 92,
            child: pw.Text(
              '$label :',
              style: _labelStyle(),
              maxLines: 1,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(value, style: _valueStyle())),
        ],
      ),
    );
  }

  static pw.Widget _summaryLine(String label, String value,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bold ? 10 : 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 10 : 9,
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

  _ShippingAddress _shippingAddress(OrderShippingInfo? s) {
    final state = _trimOrDash(s?.state);
    return _ShippingAddress(
      name: _trimOrDash(s?.displayName),
      phone: _trimOrDash(s?.phone),
      address: _trimOrDash(s?.displayAddressLine),
      city: _trimOrDash(s?.displayCity),
      pincode: _trimOrDash(s?.postalCode),
      state: _trimOrDash(s?.displayState ?? state),
    );
  }

  _PaymentInfo _paymentInfo(Order order) {
    final isCod = order.paymentMethod == OrderPaymentMethod.cod;
    final method = isCod ? 'COD' : 'Online';
    final status =
        order.paymentStatus == OrderPaymentStatus.paid ? 'Paid' : 'Pending';
    final ref = order.razorpayPaymentId?.trim();
    return _PaymentInfo(
      method: method,
      status: status,
      reference: isCod || ref == null || ref.isEmpty ? null : ref,
    );
  }

  static String _money(double amount) => formatInrAmountPdfSafe(amount);

  static List<String> _addressLines(String value) {
    return value
        .replaceAll(r'\n', '\n')
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

class _ShippingAddress {
  final String name;
  final String phone;
  final String address;
  final String city;
  final String pincode;
  final String state;

  const _ShippingAddress({
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.pincode,
    required this.state,
  });
}

class _PaymentInfo {
  final String method;
  final String status;
  final String? reference;

  const _PaymentInfo({
    required this.method,
    required this.status,
    this.reference,
  });
}
