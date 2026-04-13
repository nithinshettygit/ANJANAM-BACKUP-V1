import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/auth/account_blocking.dart';
import 'package:ecommerce_app/core/search/order_search_utils.dart';
import 'package:ecommerce_app/core/supabase/supabase_service_base.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_detail_bundle.dart';
import '../../domain/entities/order_shipping_info.dart';
import '../../domain/entities/order_status_history_entry.dart';
import '../../domain/repositories/order_history_repository.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';

class SupabaseOrderHistoryService extends SupabaseServiceBase
    implements OrderHistoryRepository {
  SupabaseOrderHistoryService(super.client);

  static const _orderSelect = 'id, user_id, status, currency, created_at, delivered_at, return_deadline, delivery_fee, '
      'tracking_number, courier_name, estimated_delivery_date, '
      'payment_method, payment_status, razorpay_payment_id, '
      'delivery_method, delivery_status, delivery_partner_name, delivery_partner_phone, shipping_provider, '
      'shipment_id, awb_code, shipment_status, tracking_url, shipped_at, last_tracking_update';

  static const _orderSelectDetail = '$_orderSelect, '
      'shipping_full_name, shipping_phone, shipping_address_line, shipping_city, shipping_postal_code, shipping_state';

  @override
  Future<List<Order>> fetchOrders() async {
    final page = await fetchOrdersPage(limit: 200, offset: 0);
    return page.orders;
  }

  @override
  Future<({List<Order> orders, bool hasMore})> fetchOrdersPage({
    int limit = 20,
    int offset = 0,
    String? search,
  }) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Sign in required to view order history.');
    }
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
      blockedMessageFallback:
          'Your account has been suspended. Please contact support for assistance.',
    );

    final needle = search?.trim();
    if (needle == null || needle.isEmpty) {
      return _fetchOrdersPagePlain(
        authUserId: authUser.id,
        limit: limit,
        offset: offset,
      );
    }
    return _fetchOrdersPageWithSearch(
      authUserId: authUser.id,
      limit: limit,
      offset: offset,
      needle: needle,
    );
  }

  Future<({List<Order> orders, bool hasMore})> _fetchOrdersPagePlain({
    required String authUserId,
    required int limit,
    required int offset,
  }) async {
    final take = limit + 1;
    final end = offset + take - 1;

    final ordersData = await guard(
      () => client
          .from('orders')
          .select(_orderSelect)
          .eq('user_id', authUserId)
          .order('created_at', ascending: false)
          .range(offset, end),
    );

    final ordersList = (ordersData as List).cast<Map<String, dynamic>>();
    final hasMore = ordersList.length > limit;
    final slice = hasMore ? ordersList.sublist(0, limit) : ordersList;

    if (slice.isEmpty) {
      return (orders: <Order>[], hasMore: false);
    }

    final orderIds =
        slice.map((e) => (e['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
    final itemsByOrder = await _fetchItemsForOrders(orderIds);

    final result = <Order>[];
    for (final json in slice) {
      final orderModel = OrderModel.fromJson(json);
      final items = itemsByOrder[orderModel.id] ?? const <OrderItemModel>[];
      result.add(orderModel.toEntity(items: items));
    }

    return (orders: result, hasMore: hasMore);
  }

  Future<({List<Order> orders, bool hasMore})> _fetchOrdersPageWithSearch({
    required String authUserId,
    required int limit,
    required int offset,
    required String needle,
  }) async {
    final qLower = needle.toLowerCase();
    final qNorm = qLower.replaceAll('-', '');
    final sanitized = sanitizeOrderSearchIlike(needle);

    final productOrderIds = <String>{};
    if (sanitized.isNotEmpty) {
      try {
        final data = await guard(
          () => client
              .from('order_items')
              .select('order_id')
              .ilike('title', '%$sanitized%'),
        );
        for (final r in (data as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          final oid = m['order_id']?.toString();
          if (oid != null && oid.isNotEmpty) productOrderIds.add(oid);
        }
      } catch (_) {}
    }

    final uuidLike = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    final trimmed = needle.trim();
    if (uuidLike.hasMatch(trimmed)) {
      try {
        final byPid = await guard(
          () => client
              .from('order_items')
              .select('order_id')
              .eq('product_id', trimmed),
        );
        for (final r in (byPid as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          final oid = m['order_id']?.toString();
          if (oid != null && oid.isNotEmpty) productOrderIds.add(oid);
        }
      } catch (_) {}
    }

    final allRows = await guard(
      () => client
          .from('orders')
          .select('id, status')
          .eq('user_id', authUserId)
          .order('created_at', ascending: false),
    );

    final filteredIds = <String>[];
    for (final row in (allRows as List).cast<Map<String, dynamic>>()) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final status = (row['status'] ?? '').toString().toLowerCase();
      if (productOrderIds.contains(id) ||
          orderIdMatchesSearch(id, qLower, qNorm) ||
          status.contains(qLower)) {
        filteredIds.add(id);
      }
    }

    if (filteredIds.isEmpty) {
      return (orders: <Order>[], hasMore: false);
    }

    final hasMore = offset + limit < filteredIds.length;
    final slice = filteredIds.skip(offset).take(limit).toList();

    if (slice.isEmpty) {
      return (orders: <Order>[], hasMore: false);
    }

    final ordersData = await guard(
      () => client.from('orders').select(_orderSelect).inFilter('id', slice),
    );
    final byId = <String, Map<String, dynamic>>{};
    for (final r in (ordersData as List).cast<Map<String, dynamic>>()) {
      final id = r['id']?.toString();
      if (id != null) byId[id] = r;
    }
    final orderedJson = <Map<String, dynamic>>[];
    for (final id in slice) {
      final row = byId[id];
      if (row != null) orderedJson.add(row);
    }

    final itemsByOrder = await _fetchItemsForOrders(slice);

    final result = <Order>[];
    for (final json in orderedJson) {
      final orderModel = OrderModel.fromJson(json);
      final items = itemsByOrder[orderModel.id] ?? const <OrderItemModel>[];
      result.add(orderModel.toEntity(items: items));
    }

    return (orders: result, hasMore: hasMore);
  }

  Future<Map<String, List<OrderItemModel>>> _fetchItemsForOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return {};
    final itemsData = await guard(
      () => client
          .from('order_items')
          .select('id, order_id, product_id, title, image_urls, unit_price, currency, quantity')
          .inFilter('order_id', orderIds)
          .order('created_at', ascending: true),
    );

    final map = <String, List<OrderItemModel>>{};
    for (final row in (itemsData as List).cast<Map<String, dynamic>>()) {
      final oid = (row['order_id'] ?? '').toString();
      if (oid.isEmpty) continue;
      map.putIfAbsent(oid, () => []).add(OrderItemModel.fromJson(row));
    }
    return map;
  }

  @override
  Future<Order> fetchOrderById(String orderId) async {
    final bundle = await fetchOrderDetailBundle(orderId);
    return bundle.order;
  }

  @override
  Future<OrderDetailBundle> fetchOrderDetailBundle(String orderId) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Sign in required to view orders.');
    }
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
      blockedMessageFallback:
          'Your account has been suspended. Please contact support for assistance.',
    );

    Map<String, dynamic> data;
    try {
      data = await guard(
        () => client
            .from('orders')
            .select(_orderSelectDetail)
            .eq('id', orderId)
            .eq('user_id', authUser.id)
            .single(),
      );
    } catch (_) {
      data = await guard(
        () => client
            .from('orders')
            .select(_orderSelect)
            .eq('id', orderId)
            .eq('user_id', authUser.id)
            .single(),
      );
    }

    final orderModel = OrderModel.fromJson(data);
    final itemsData = await guard(
      () => client
          .from('order_items')
          .select('id, order_id, product_id, title, image_urls, unit_price, currency, quantity')
          .eq('order_id', orderId)
          .order('created_at', ascending: true),
    );
    final itemsList = (itemsData as List).cast<Map<String, dynamic>>();
    final items = itemsList.map((e) => OrderItemModel.fromJson(e)).toList();

    final historyData = await guard(
      () => client
          .from('order_status_history')
          .select('id, status, notes, created_at')
          .eq('order_id', orderId)
          .order('created_at', ascending: true),
    );

    final historyList = (historyData as List).cast<Map<String, dynamic>>();
    final history = historyList.map((row) {
      return OrderStatusHistoryEntry(
        id: (row['id'] ?? '').toString(),
        status: OrderStatusX.fromDbValue((row['status'] ?? '').toString()),
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now(),
        notes: () {
          final n = row['notes']?.toString().trim();
          return n != null && n.isNotEmpty ? n : null;
        }(),
      );
    }).toList();

    final shipping = _parseShipping(data);

    return OrderDetailBundle(
      order: orderModel.toEntity(items: items),
      statusHistory: history,
      shipping: shipping,
    );
  }

  static OrderShippingInfo? _parseShipping(Map<String, dynamic> row) {
    final name = row['shipping_full_name']?.toString().trim();
    final phone = row['shipping_phone']?.toString().trim();
    final line = row['shipping_address_line']?.toString().trim();
    final city = row['shipping_city']?.toString().trim();
    final pin = row['shipping_postal_code']?.toString().trim();
    final info = OrderShippingInfo(
      fullName: name != null && name.isNotEmpty ? name : null,
      phone: phone != null && phone.isNotEmpty ? phone : null,
      addressLine: line != null && line.isNotEmpty ? line : null,
      city: city != null && city.isNotEmpty ? city : null,
      postalCode: pin != null && pin.isNotEmpty ? pin : null,
    );
    return info.hasStructuredAddress ? info : null;
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Sign in required.');
    }
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
      blockedMessageFallback:
          'Your account has been suspended. Please contact support for assistance.',
    );
    try {
      await guard(
        () => client.rpc(
          'cancel_my_order',
          params: {
            'p_order_id': orderId,
            'p_notes': reason,
          },
        ),
      );
    } on RepositoryException catch (e) {
      final raw = e.message.toLowerCase();
      if (raw.contains('use_request_cancel_for_processing_or_packed')) {
        throw const ValidationException(
          'Use the cancellation request flow for orders that are already being prepared.',
        );
      }
      if (raw.contains('cannot_cancel_shipped_order')) {
        throw const ValidationException(
          'This order can no longer be cancelled because it has moved past processing (for example, it may have shipped). Contact support if you need help.',
        );
      }
      if (raw.contains('order_not_found')) {
        throw const ValidationException('We could not find that order.');
      }
      if (raw.contains('not_authorized')) {
        throw const ValidationException('You can only cancel your own orders.');
      }
      if (raw.contains('not_authenticated')) {
        throw const AuthException('Sign in required.');
      }
      rethrow;
    }
  }

  @override
  Future<void> requestOrderCancellation(String orderId, {String? reason}) async {
    final authUser = client.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('Sign in required.');
    }
    await ensureUserIsNotBlocked(
      client,
      userId: authUser.id,
      signOutIfBlocked: true,
      blockedMessageFallback:
          'Your account has been suspended. Please contact support for assistance.',
    );
    try {
      await guard(
        () => client.rpc(
          'request_cancel_my_order',
          params: {
            'p_order_id': orderId,
            'p_notes': reason,
          },
        ),
      );
    } on RepositoryException catch (e) {
      final raw = e.message.toLowerCase();
      if (raw.contains('cancellation_request_not_allowed_after_shipped')) {
        throw const ValidationException(
          'This order has already shipped or been handed to the courier. Cancellation can no longer be requested. Contact support if you need help.',
        );
      }
      if (raw.contains('cancellation_request_not_allowed_for_status')) {
        throw const ValidationException(
          'Cancellation can only be requested while the order is processing or packed and has not yet shipped.',
        );
      }
      if (raw.contains('order_not_found')) {
        throw const ValidationException('We could not find that order.');
      }
      if (raw.contains('not_authorized')) {
        throw const ValidationException('You can only cancel your own orders.');
      }
      if (raw.contains('not_authenticated')) {
        throw const AuthException('Sign in required.');
      }
      rethrow;
    }
  }
}
