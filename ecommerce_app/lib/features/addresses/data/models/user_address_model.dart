import '../../domain/entities/user_address.dart';

class UserAddressModel {
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

  UserAddressModel({
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

  factory UserAddressModel.fromJson(Map<String, dynamic> json) {
    return UserAddressModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      addressLine: json['address_line']?.toString() ?? '',
      addressLine2: json['address_line2']?.toString(),
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString(),
      postalCode: json['postal_code']?.toString() ?? '',
      country: json['country']?.toString(),
      isDefault: json['is_default'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() => <String, dynamic>{
        'full_name': fullName,
        'phone': phone,
        'address_line': addressLine,
        if (addressLine2 != null) 'address_line2': addressLine2,
        'city': city,
        if (state != null) 'state': state,
        'postal_code': postalCode,
        if (country != null) 'country': country,
        'is_default': isDefault,
      };

  UserAddress toEntity() => UserAddress(
        id: id,
        userId: userId,
        fullName: fullName,
        phone: phone,
        addressLine: addressLine,
        addressLine2: addressLine2,
        city: city,
        state: state,
        postalCode: postalCode,
        country: country,
        isDefault: isDefault,
        createdAt: createdAt,
      );
}
