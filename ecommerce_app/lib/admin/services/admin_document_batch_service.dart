import 'dart:typed_data';

import 'package:ecommerce_app/core/invoice/invoice_generator.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_service.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_shipping_info.dart';

import 'admin_service.dart';

class AdminDocumentBatchService {
  final AdminService adminService;

  const AdminDocumentBatchService(this.adminService);

  Future<Uint8List> generateInvoices(List<AdminOrderRow> rows) async {
    final details = await _loadDetails(rows);
    final inputs = details.map(_invoiceInputFor).toList();
    if (inputs.any((input) => input.items.isEmpty)) {
      throw const AdminDocumentBatchException(
        'One or more selected orders have no items for an invoice.',
      );
    }
    return InvoiceGenerator().generateInvoicePdfBatch(inputs);
  }

  Future<Uint8List> generateLabels(List<AdminOrderRow> rows) async {
    final details = await _loadDetails(rows);
    return ShippingLabelService().generateCombinedPdfBatch(details);
  }

  Future<List<AdminOrderDetails>> _loadDetails(
    List<AdminOrderRow> rows,
  ) async {
    return Future.wait(
      rows.map((row) => adminService.fetchOrderDetails(row.id)),
    );
  }

  InvoicePdfInput _invoiceInputFor(AdminOrderDetails details) {
    return InvoicePdfInput(
      order: _orderForInvoice(details),
      items: details.items.map(_itemForInvoice).toList(),
      shipping: _shippingForInvoice(details),
    );
  }

  Order _orderForInvoice(AdminOrderDetails details) {
    final order = details.order;
    return Order(
      id: order.id,
      userId: order.userId,
      status: OrderStatusX.fromDbValue(order.status),
      items: details.items.map(_itemForInvoice).toList(),
      currency: order.currency,
      createdAt: order.createdAt,
      deliveryFee: order.deliveryFee,
      trackingNumber: details.trackingNumber,
      courierName: details.courierName,
      estimatedDeliveryDate: details.estimatedDeliveryDate,
      paymentMethod: orderPaymentMethodFromDb(order.paymentMethod),
      paymentStatus: orderPaymentStatusFromDb(order.paymentStatus),
      razorpayPaymentId: details.razorpayPaymentId ?? order.razorpayPaymentId,
      returnDeadline: null,
    );
  }

  OrderItem _itemForInvoice(AdminOrderItemRow item) {
    return OrderItem(
      variantId: item.variantId,
      productId: item.productId,
      title: item.title,
      imageUrls: item.imageUrls,
      unitPrice: item.unitPrice,
      currency: item.currency,
      quantity: item.quantity,
      hsnCode: item.hsnCode,
      taxStatus: item.taxStatus,
      taxableValue: item.taxableValue,
      gstRate: item.gstRate,
      cgstAmount: item.cgstAmount,
      sgstAmount: item.sgstAmount,
      igstAmount: item.igstAmount,
      priceIncludesGst: item.priceIncludesGst,
    );
  }

  OrderShippingInfo _shippingForInvoice(AdminOrderDetails details) {
    final hasStructuredShipping = details.shippingFullName != null ||
        details.shippingPhone != null ||
        details.shippingAddressLine != null ||
        details.shippingCity != null ||
        details.shippingPostalCode != null ||
        details.shippingState != null;
    final addressLine = hasStructuredShipping
        ? details.shippingAddressLine
        : (details.shippingAddress.trim().isEmpty
            ? null
            : details.shippingAddress.trim());
    final name = details.shippingFullName?.trim().isNotEmpty == true
        ? details.shippingFullName!.trim()
        : details.order.customerName.trim();

    return OrderShippingInfo(
      fullName: name.isEmpty ? null : name,
      phone: details.shippingPhone,
      addressLine: addressLine,
      city: details.shippingCity,
      state: details.shippingState,
      postalCode: details.shippingPostalCode,
      invoiceName: details.invoiceName,
      invoiceAddressLine: details.invoiceAddressLine,
      invoiceCity: details.invoiceCity,
      invoiceState: details.invoiceState,
    );
  }
}

class AdminDocumentBatchException implements Exception {
  final String message;

  const AdminDocumentBatchException(this.message);

  @override
  String toString() => message;
}
