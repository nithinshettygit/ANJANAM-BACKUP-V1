import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import '../data/services/order_payment_service.dart';

final orderPaymentServiceProvider = Provider<OrderPaymentService>((ref) {
  return OrderPaymentService(ref.watch(supabaseClientProvider));
});
