import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/supabase_user_address_service.dart';
import '../domain/entities/user_address.dart';
import '../domain/repositories/user_address_repository.dart';

final userAddressRepositoryProvider = Provider<UserAddressRepository>((ref) {
  return SupabaseUserAddressService(ref.watch(supabaseClientProvider));
});

final userAddressesProvider =
    FutureProvider.autoDispose<List<UserAddress>>((ref) async {
  return ref.watch(userAddressRepositoryProvider).listAddresses();
});
