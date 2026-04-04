import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';

import '../../domain/entities/user_address.dart';
import '../../domain/repositories/user_address_repository.dart';
import '../models/user_address_model.dart';

class SupabaseUserAddressService extends SupabaseServiceBase
    implements UserAddressRepository {
  SupabaseUserAddressService(super.client);

  @override
  Future<List<UserAddress>> listAddresses() async {
    final data = await guard(
      () => client
          .from('user_addresses')
          .select()
          .order('is_default', ascending: false)
          .order('created_at', ascending: false),
    );
    final list = (data as List).cast<Map<String, dynamic>>();
    return list.map((e) => UserAddressModel.fromJson(e).toEntity()).toList();
  }

  @override
  Future<UserAddress> createAddress({
    required String fullName,
    required String phone,
    required String addressLine,
    String? addressLine2,
    required String city,
    String? state,
    required String postalCode,
    String? country,
    bool isDefault = false,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    final payload = {
      'user_id': uid,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'address_line': addressLine.trim(),
      'address_line2': addressLine2?.trim(),
      'city': city.trim(),
      'state': state?.trim(),
      'postal_code': postalCode.trim(),
      'country': country?.trim(),
      'is_default': isDefault,
    };
    late final dynamic row;
    try {
      row = await guard(
        () => client.from('user_addresses').insert(payload).select().single(),
      );
    } catch (_) {
      // Backward compatibility for DBs where line2/state/country columns are not migrated yet.
      row = await guard(
        () => client.from('user_addresses').insert({
              'user_id': uid,
              'full_name': fullName.trim(),
              'phone': phone.trim(),
              'address_line': addressLine.trim(),
              'city': city.trim(),
              'postal_code': postalCode.trim(),
              'is_default': isDefault,
            }).select().single(),
      );
    }
    return UserAddressModel.fromJson(Map<String, dynamic>.from(row)).toEntity();
  }

  @override
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
  }) async {
    final patch = <String, dynamic>{
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'address_line': addressLine.trim(),
      'address_line2': addressLine2?.trim(),
      'city': city.trim(),
      'state': state?.trim(),
      'postal_code': postalCode.trim(),
      'country': country?.trim(),
    };
    if (isDefault != null) {
      patch['is_default'] = isDefault;
    }
    try {
      await guard(
        () => client.from('user_addresses').update(patch).eq('id', id),
      );
    } catch (_) {
      await guard(
        () => client.from('user_addresses').update({
              'full_name': fullName.trim(),
              'phone': phone.trim(),
              'address_line': addressLine.trim(),
              'city': city.trim(),
              'postal_code': postalCode.trim(),
              if (isDefault != null) 'is_default': isDefault,
            }).eq('id', id),
      );
    }
  }

  @override
  Future<void> deleteAddress(String id) async {
    await guard(() => client.from('user_addresses').delete().eq('id', id));
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    await guard(
      () => client.from('user_addresses').update({'is_default': true}).eq('id', id),
    );
  }
}
