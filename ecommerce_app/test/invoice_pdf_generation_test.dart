import 'dart:io';

import 'package:ecommerce_app/core/document_settings/document_settings.dart';
import 'package:ecommerce_app/core/invoice/invoice_generator.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_data.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_generator.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_shipping_info.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates an inspectable invoice PDF with Indic address fallback',
      () async {
    final order = Order(
      id: '84e6fd58-0000-0000-0000-000000000000',
      userId: 'user-1',
      status: OrderStatus.processing,
      items: const [
        OrderItem(
          productId: 'product-1',
          title: 'Agnihotra Kit',
          imageUrls: [],
          unitPrice: 1180,
          currency: 'INR',
          quantity: 1,
          hsnCode: 'XXXXXXXX',
          taxStatus: 'taxable',
          taxableValue: 1000,
          gstRate: 18,
          cgstAmount: 90,
          sgstAmount: 90,
          igstAmount: 0,
          priceIncludesGst: true,
        ),
      ],
      currency: 'INR',
      createdAt: DateTime.utc(2026, 9, 12),
    );

    const shipping = OrderShippingInfo(
      fullName: 'ನಿತಿನ್',
      phone: '8129107108',
      addressLine: 'ಬೇಂದ್ರೆ ಹೌಸ್\nಮುಖ್ಯ ರಸ್ತೆ',
      city: 'ಬಂಟ್ವಾಳ',
      state: 'ಕರ್ನಾಟಕ',
      postalCode: '574211',
      invoiceName: 'Nithin',
      invoiceAddressLine: 'Bendre House\nMukhya Road',
      invoiceCity: 'Bantwal',
      invoiceState: 'Karnataka',
    );
    expect(shipping.fullName, 'ನಿತಿನ್');
    expect(shipping.addressLine, 'ಬೇಂದ್ರೆ ಹೌಸ್\nಮುಖ್ಯ ರಸ್ತೆ');
    expect(shipping.displayName, 'Nithin');
    expect(shipping.displayAddressLine, 'Bendre House\nMukhya Road');

    final bytes = await InvoiceGenerator().generateInvoicePdf(
      order,
      order.items,
      shipping: shipping,
      settingsOverride: const DocumentSettings(
        sellerLegalName: 'Anjanam',
        sellerAddress:
            'Anjanam Warehouse\\nMUGU, Kasaragod\\nKerala, India 671321',
        sellerPhone: '+91 81291 07108',
        sellerEmail: 'support.anjanam@gmail.com',
        sellerGstin: '32CQRPM1694P1ZZ',
        labelFromAddressLines: [
          'Anjanam Warehouse',
          'MUGU, Kasaragod',
          'Kerala, India 671321',
        ],
      ),
    );

    expect(bytes.length, greaterThan(1000));
    final output = File('build/invoice_pdf_generation_test.pdf');
    await output.writeAsBytes(bytes, flush: true);
    expect(await output.exists(), isTrue);

    final batchBytes = await InvoiceGenerator().generateInvoicePdfBatch([
      InvoicePdfInput(order: order, items: order.items, shipping: shipping),
      InvoicePdfInput(order: order, items: order.items, shipping: shipping),
    ],
        settingsOverride: const DocumentSettings(
          sellerLegalName: 'Anjanam',
          sellerAddress:
              'Anjanam Warehouse\\nMUGU, Kasaragod\\nKerala, India 671321',
          sellerPhone: '+91 81291 07108',
          sellerEmail: 'support.anjanam@gmail.com',
          sellerGstin: '32CQRPM1694P1ZZ',
          labelFromAddressLines: [
            'Anjanam Warehouse',
            'MUGU, Kasaragod',
            'Kerala, India 671321',
          ],
        ));
    expect(batchBytes.length, greaterThan(bytes.length));

    final label = ShippingLabelData(
      orderId: '84e6fd58-0000-0000-0000-000000000000',
      orderIdDisplay: '#000000',
      orderDate: DateTime.utc(2026, 9, 12),
      customerName: 'Nithin',
      phone: '8129107108',
      shipToLines: ['Bendre House', 'Bantwal', 'Karnataka 574211'],
      fromAddressLines: ['Anjanam', 'MUGU, Kasaragod'],
      barcodeData: '84e6fd58-0000-0000-0000-000000000000',
      qrData:
          'https://anjanam.store/order/84e6fd58-0000-0000-0000-000000000000',
    );
    final labelBytes = await ShippingLabelGenerator().generateLabelPdf(label);
    final labelBatchBytes =
        await ShippingLabelGenerator().generateLabelPdfBatch([label, label]);
    expect(labelBatchBytes.length, greaterThan(labelBytes.length));
  });
}
