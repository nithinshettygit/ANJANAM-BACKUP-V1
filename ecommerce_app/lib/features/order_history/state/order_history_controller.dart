import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import '../data/services/supabase_order_history_service.dart';
import '../domain/entities/order.dart';
import '../domain/repositories/order_history_repository.dart';

final orderHistoryRepositoryProvider = Provider<OrderHistoryRepository>(
  (ref) => SupabaseOrderHistoryService(ref.watch(supabaseClientProvider)),
);

/// My Orders search (debounced updates recommended in UI).
final orderHistorySearchQueryProvider =
    NotifierProvider<OrderHistorySearchQueryNotifier, String>(
  OrderHistorySearchQueryNotifier.new,
);

class OrderHistorySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

class OrderHistoryListState {
  final List<Order> orders;
  final bool hasMore;
  final bool isLoadingMore;

  const OrderHistoryListState({
    required this.orders,
    required this.hasMore,
    this.isLoadingMore = false,
  });
}

class OrderHistoryController extends AsyncNotifier<OrderHistoryListState> {
  OrderHistoryRepository get _repo => ref.read(orderHistoryRepositoryProvider);

  static const _pageSize = 15;

  bool _loadingMore = false;

  String? _searchFromRead() {
    final t = ref.read(orderHistorySearchQueryProvider).trim();
    return t.isEmpty ? null : t;
  }

  @override
  Future<OrderHistoryListState> build() async {
    ref.watch(orderHistorySearchQueryProvider);
    final page = await _repo.fetchOrdersPage(
      limit: _pageSize,
      offset: 0,
      search: _searchFromRead(),
    );
    return OrderHistoryListState(orders: page.orders, hasMore: page.hasMore);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final page = await _repo.fetchOrdersPage(
      limit: _pageSize,
      offset: 0,
      search: _searchFromRead(),
    );
    state = AsyncValue.data(
      OrderHistoryListState(orders: page.orders, hasMore: page.hasMore),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    state = AsyncValue.data(
      OrderHistoryListState(
        orders: current.orders,
        hasMore: current.hasMore,
        isLoadingMore: true,
      ),
    );
    try {
      final page = await _repo.fetchOrdersPage(
        limit: _pageSize,
        offset: current.orders.length,
        search: _searchFromRead(),
      );
      state = AsyncValue.data(
        OrderHistoryListState(
          orders: [...current.orders, ...page.orders],
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(
        OrderHistoryListState(
          orders: current.orders,
          hasMore: current.hasMore,
          isLoadingMore: false,
        ),
      );
    } finally {
      _loadingMore = false;
    }
  }
}

final orderHistoryControllerProvider =
    AsyncNotifierProvider<OrderHistoryController, OrderHistoryListState>(
  OrderHistoryController.new,
);
