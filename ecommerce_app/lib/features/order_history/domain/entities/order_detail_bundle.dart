import 'order.dart';
import 'order_shipping_info.dart';
import 'order_status_history_entry.dart';

class OrderDetailBundle {
  final Order order;
  final List<OrderStatusHistoryEntry> statusHistory;
  final OrderShippingInfo? shipping;

  const OrderDetailBundle({
    required this.order,
    required this.statusHistory,
    this.shipping,
  });
}
