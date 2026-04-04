import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/order_detail_bundle.dart';
import 'order_history_controller.dart';

final orderDetailBundleProvider =
    FutureProvider.autoDispose.family<OrderDetailBundle, String>(
  (ref, orderId) =>
      ref.read(orderHistoryRepositoryProvider).fetchOrderDetailBundle(orderId),
);
