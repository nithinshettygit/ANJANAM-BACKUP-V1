import 'dart:async';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/core/theme/wishlist_heart_sizes.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/order_history/state/order_detail_provider.dart';
import 'package:ecommerce_app/features/order_history/state/order_history_controller.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_provider.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/widgets/order_history_order_card.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeChannel,
        SupabaseClient;

class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  RealtimeChannel? _ordersRealtimeChannel;
  SupabaseClient? _ordersRealtimeClient;

  @override
  void initState() {
    super.initState();
    _subscribeMyOrdersRealtime();
    ref.listenManual<Map<int, int>>(
      storefrontScrollToTopSignalProvider,
      (previous, next) {
        final prevSignal = previous?[StorefrontTab.orders.shellIndex] ?? 0;
        final nextSignal = next[StorefrontTab.orders.shellIndex] ?? 0;
        if (nextSignal == prevSignal) return;
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    final ch = _ordersRealtimeChannel;
    final cl = _ordersRealtimeClient;
    if (ch != null && cl != null) {
      cl.removeChannel(ch);
      _ordersRealtimeChannel = null;
      _ordersRealtimeClient = null;
    }
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeMyOrdersRealtime() {
    final client = ref.read(supabaseClientProvider);
    _ordersRealtimeClient = client;
    final uid = client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return;

    final channel = client.channel('storefront-my-orders-$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: uid,
      ),
      callback: (payload) {
        if (!mounted) return;
        try {
          final nr = (payload as dynamic).newRecord;
          if (nr is Map) {
            final id = nr['id']?.toString();
            if (id != null && id.isNotEmpty) {
              ref.invalidate(orderDetailBundleProvider(id));
            }
          }
        } catch (_) {}
        ref.invalidate(orderHistoryControllerProvider);
      },
    );
    channel.subscribe();
    _ordersRealtimeChannel = channel;
  }

  void _scheduleSearchCommit(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      final next = value.trim();
      final cur = ref.read(orderHistorySearchQueryProvider).trim();
      if (next == cur) return;
      ref.read(orderHistorySearchQueryProvider.notifier).set(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderHistoryControllerProvider);
    final wishlistCount = ref.watch(wishlistProvider).length;
    final cart = ref.watch(
      cartControllerProvider.select((async) => async.value),
    );
    final cartItemCount = cart?.items.fold<int>(0, (sum, e) => sum + e.quantity) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(orderHistoryControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Wishlist',
            iconSize: WishlistHeartSizes.appBar,
            onPressed: () => Navigator.of(context).pushNamed('/wishlist'),
            icon: Badge(
              isLabelVisible: wishlistCount > 0,
              label: Text('$wishlistCount'),
              child: Icon(Icons.favorite_border, size: WishlistHeartSizes.appBar),
            ),
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: () => navigateToCartPage(ref, context),
            icon: Badge(
              isLabelVisible: cartItemCount > 0,
              label: Text('$cartItemCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Search by order id, status, or product…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      _searchDebounce?.cancel();
                      ref.read(orderHistorySearchQueryProvider.notifier).set('');
                    },
                  ),
              ],
              onChanged: (v) {
                _scheduleSearchCommit(v);
                setState(() {});
              },
              onSubmitted: (v) {
                _searchDebounce?.cancel();
                ref.read(orderHistorySearchQueryProvider.notifier).set(v.trim());
              },
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              data: (listState) {
                final hasSearch =
                    ref.watch(orderHistorySearchQueryProvider).trim().isNotEmpty;
                if (listState.orders.isEmpty) {
                  return PageRefreshableBody(
                    onRefresh: () =>
                        ref.read(orderHistoryControllerProvider.notifier).refresh(),
                    child: PageEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: hasSearch ? 'No matching orders' : 'No orders yet',
                      subtitle: hasSearch
                          ? 'Try different keywords or clear the search.'
                          : 'When you place an order, it will show up here.',
                      action: FilledButton.tonal(
                        onPressed: () {
                          if (hasSearch) {
                            _searchCtrl.clear();
                                ref
                                    .read(orderHistorySearchQueryProvider.notifier)
                                    .set('');
                            setState(() {});
                          } else {
                            Navigator.of(context).pushNamed('/catalog');
                          }
                        },
                        child: Text(hasSearch ? 'Clear search' : 'Start shopping'),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(orderHistoryControllerProvider.notifier).refresh(),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification n) {
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent - 320) {
                        ref.read(orderHistoryControllerProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 10, bottom: 24),
                      itemCount: listState.orders.length +
                          (listState.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= listState.orders.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          );
                        }
                        return OrderHistoryOrderCard(order: listState.orders[index]);
                      },
                    ),
                  ),
                );
              },
              loading: () => const PageLoading(message: 'Loading orders...'),
              error: (error, _) => PageRefreshableBody(
                onRefresh: () =>
                    ref.read(orderHistoryControllerProvider.notifier).refresh(),
                child: PageErrorState(
                  title: 'Could not load orders',
                  message:
                      'Sign in may be required, or try again.\n${error.toString()}',
                  onRetry: () => ref.invalidate(orderHistoryControllerProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
