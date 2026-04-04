import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/returns/data/return_record.dart';
import 'package:ecommerce_app/features/returns/data/returns_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final returnsServiceProvider = Provider<ReturnsService>(
  (ref) => ReturnsService(ref.watch(supabaseClientProvider)),
);

final orderReturnsProvider =
    FutureProvider.autoDispose.family<List<ReturnRecord>, String>(
  (ref, orderId) =>
      ref.watch(returnsServiceProvider).fetchReturnsForOrder(orderId),
);
