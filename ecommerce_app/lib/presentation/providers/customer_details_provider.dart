import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';

class CustomerDetailsData {
  final String customerName;
  final String email;
  final String phone;
  final String address;
  final int totalOrders;
  final double totalRevenue;
  final DateTime? lastOrderDate;
  final DateTime? firstOrderDate;
  final double averageOrderValue;

  const CustomerDetailsData({
    required this.customerName,
    required this.email,
    required this.phone,
    required this.address,
    required this.totalOrders,
    required this.totalRevenue,
    required this.lastOrderDate,
    required this.firstOrderDate,
    required this.averageOrderValue,
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
    // Backward compatibility for DBs where new profile fields do not exist yet.
    profile = await client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();
  }

  final ordersData = await client
      .from('orders')
      .select('id, created_at')
      .eq('user_id', user.id)
      .order('created_at', ascending: false);
  final orders = (ordersData as List).cast<Map<String, dynamic>>();
  final orderIds = orders
      .map((e) => (e['id'] ?? '').toString())
      .where((id) => id.isNotEmpty)
      .toList();

  double totalRevenue = 0;
  if (orderIds.isNotEmpty) {
    final itemsData = await client
        .from('order_items')
        .select('order_id, unit_price, quantity')
        .inFilter('order_id', orderIds);
    for (final row in (itemsData as List).cast<Map<String, dynamic>>()) {
      final unitPrice = (row['unit_price'] as num?)?.toDouble() ?? 0;
      final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
      totalRevenue += unitPrice * quantity;
    }
  }

  final allDates = orders
      .map((e) => DateTime.tryParse(e['created_at']?.toString() ?? ''))
      .whereType<DateTime>()
      .toList()
    ..sort((a, b) => a.compareTo(b));

  final totalOrders = orders.length;
  final averageOrderValue = totalOrders == 0 ? 0.0 : totalRevenue / totalOrders;

  final fullName = profile?['full_name']?.toString().trim();
  return CustomerDetailsData(
    customerName: (fullName != null && fullName.isNotEmpty) ? fullName : 'User',
    email: user.email ?? '-',
    phone: profile?['phone']?.toString() ?? '-',
    address: profile?['address']?.toString() ?? '-',
    totalOrders: totalOrders,
    totalRevenue: totalRevenue,
    lastOrderDate: allDates.isEmpty ? null : allDates.last,
    firstOrderDate: allDates.isEmpty ? null : allDates.first,
    averageOrderValue: averageOrderValue,
  );
});
