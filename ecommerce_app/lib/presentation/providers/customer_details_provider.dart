import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';

class CustomerDetailsData {
  final String customerName;
  final String email;
  final String phone;
  final String address;

  const CustomerDetailsData({
    required this.customerName,
    required this.email,
    required this.phone,
    required this.address,
  });
}

final customerDetailsProvider = FutureProvider.autoDispose<CustomerDetailsData>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) {
    throw Exception('Please login to view customer details.');
  }

  Map<String, dynamic>? profile;
  try {
    profile = await client
        .from('profiles')
        .select('full_name, phone, address')
        .eq('id', user.id)
        .maybeSingle();
  } catch (_) {
    profile = await client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();
  }

  final fullName = profile?['full_name']?.toString().trim();
  return CustomerDetailsData(
    customerName: (fullName != null && fullName.isNotEmpty) ? fullName : 'User',
    email: user.email ?? '-',
    phone: profile?['phone']?.toString() ?? '-',
    address: profile?['address']?.toString() ?? '-',
  );
});
