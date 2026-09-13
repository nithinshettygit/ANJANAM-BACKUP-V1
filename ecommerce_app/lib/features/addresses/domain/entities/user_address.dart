import 'package:ecommerce_app/features/checkout/domain/shipping_details.dart';

class UserAddress {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String addressLine;
  final String? addressLine2;
  final String city;
  final String? state;
  final String postalCode;
  final String? country;
  final bool isDefault;
  final DateTime createdAt;

  const UserAddress({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.addressLine,
    this.addressLine2,
    required this.city,
    this.state,
    required this.postalCode,
    this.country,
    required this.isDefault,
    required this.createdAt,
  });

  ShippingDetails toShippingDetails() => ShippingDetails(
        fullName: fullName,
        phone: phone,
        addressLine: [
          addressLine.trim(),
          if ((addressLine2 ?? '').trim().isNotEmpty) addressLine2!.trim(),
        ].join(', '),
        city: city,
        postalCode: postalCode,
        state: state,
      );
}
