import 'order_status.dart';

class OrderStatusHistoryEntry {
  final String id;
  final OrderStatus status;
  final DateTime createdAt;
  final String? notes;

  const OrderStatusHistoryEntry({
    required this.id,
    required this.status,
    required this.createdAt,
    this.notes,
  });
}
