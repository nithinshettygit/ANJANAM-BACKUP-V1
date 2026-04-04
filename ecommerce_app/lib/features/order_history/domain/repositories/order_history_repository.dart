import '../entities/order.dart';
import '../entities/order_detail_bundle.dart';

abstract class OrderHistoryRepository {
  Future<List<Order>> fetchOrders();

  /// Fetches [limit]+1 rows internally to detect [hasMore].
  /// [search] matches order id, status, or line-item title / product id (own orders only).
  Future<({List<Order> orders, bool hasMore})> fetchOrdersPage({
    int limit = 20,
    int offset = 0,
    String? search,
  });

  Future<Order> fetchOrderById(String orderId);

  Future<OrderDetailBundle> fetchOrderDetailBundle(String orderId);

  Future<void> cancelOrder(String orderId, {String? reason});

  /// Requests admin-reviewed cancellation (allowed when order is processing or packed).
  Future<void> requestOrderCancellation(String orderId, {String? reason});
}

