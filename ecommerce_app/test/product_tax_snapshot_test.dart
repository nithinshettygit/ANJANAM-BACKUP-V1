import 'package:flutter_test/flutter_test.dart';
import 'package:ecommerce_app/features/checkout/domain/shipping_details.dart';
import 'package:ecommerce_app/features/order_history/data/models/order_item_model.dart';
import 'package:ecommerce_app/admin/services/admin_service.dart';

void main() {
  test('order item preserves immutable product tax snapshot fields', () {
    final item = OrderItemModel.fromJson({
      'order_id': 'order-1',
      'product_id': 'product-1',
      'title': 'Agnihotra Kit',
      'image_urls': <String>[],
      'unit_price': 1180,
      'currency': 'INR',
      'quantity': 1,
      'hsn_code': 'XXXXXXXX',
      'tax_status': 'taxable',
      'taxable_value': 1000,
      'gst_rate': 18,
      'cgst_amount': 90,
      'sgst_amount': 90,
      'igst_amount': 0,
      'price_includes_gst': true,
    });

    final entity = item.toEntity();
    expect(entity.hsnCode, 'XXXXXXXX');
    expect(entity.taxStatus, 'taxable');
    expect(entity.taxableValue, 1000);
    expect(entity.gstRate, 18);
    expect(entity.cgstAmount, 90);
    expect(entity.sgstAmount, 90);
    expect(entity.igstAmount, 0);
    expect(entity.priceIncludesGst, isTrue);
  });

  test('shipping state is included in the server checkout payload', () {
    final details = ShippingDetails(
      fullName: 'Customer',
      phone: '9876543210',
      addressLine: 'Street',
      city: 'Kochi',
      postalCode: '682001',
      state: 'Kerala',
    );

    expect(details.toRpcJson()['state'], 'Kerala');
  });

  test('AdminProduct preserves HSN Code and GST Rate during image normalization', () {
    final rawJson = <String, dynamic>{
      'id': 'test-prod-1',
      'title': 'Test Product',
      'description': 'Test Desc',
      'category': 'incense',
      'price': 100,
      'currency': 'INR',
      'inventory_count': 10,
      'image_urls': ['https://example.com/img1.jpg'],
      'hsn_code': '1404',
      'gst_rate': 5.0,
      'tax_status': 'taxable',
      'price_includes_gst': true,
    };

    final product = AdminProduct.fromJson(rawJson);
    expect(product.hsnCode, '1404');
    expect(product.gstRate, 5.0);
    expect(product.taxStatus, 'taxable');
    expect(product.priceIncludesGst, isTrue);
  });
}
