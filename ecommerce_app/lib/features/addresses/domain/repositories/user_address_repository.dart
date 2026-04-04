import '../entities/user_address.dart';

abstract class UserAddressRepository {
  Future<List<UserAddress>> listAddresses();
  Future<UserAddress> createAddress({
    required String fullName,
    required String phone,
    required String addressLine,
    String? addressLine2,
    required String city,
    String? state,
    required String postalCode,
    String? country,
    bool isDefault,
  });
  Future<void> updateAddress({
    required String id,
    required String fullName,
    required String phone,
    required String addressLine,
    String? addressLine2,
    required String city,
    String? state,
    required String postalCode,
    String? country,
    bool? isDefault,
  });
  Future<void> deleteAddress(String id);
  Future<void> setDefaultAddress(String id);
}
