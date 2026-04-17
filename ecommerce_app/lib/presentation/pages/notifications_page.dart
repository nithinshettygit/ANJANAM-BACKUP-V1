import 'dart:async';

import 'package:ecommerce_app/core/notifications/notification_tap_navigator.dart';
import 'package:ecommerce_app/core/theme/wishlist_heart_sizes.dart';
import 'package:ecommerce_app/features/cart/state/cart_controller.dart';
import 'package:ecommerce_app/features/notifications/state/app_notification.dart';
import 'package:ecommerce_app/features/notifications/state/notifications_controller.dart';
import 'package:ecommerce_app/features/wishlist/state/wishlist_provider.dart';
import 'package:ecommerce_app/presentation/utils/main_shell_navigation.dart';
import 'package:ecommerce_app/presentation/widgets/app_network_image.dart';
import 'package:ecommerce_app/presentation/widgets/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final state = ref.read(notificationsControllerProvider).value;
    // If controller isn't ready yet, skip.
    if (state == null) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (_scrollCtrl.position.pixels >= max - 300) {
      ref.read(notificationsControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openNotificationTarget(AppNotification n) async {
    await ref.read(notificationsControllerProvider.notifier).markAsRead(n.id);
    if (!mounted) return;

    final data = <String, dynamic>{
      'notification_id': n.id,
      'kind': n.kind,
      'title': n.title,
      'message': n.message,
      'redirect_type': n.redirectType ?? '',
      'redirect_value': n.redirectValue ?? '',
      'image_url': n.imageUrl ?? '',
      if (n.orderId != null && n.orderId!.isNotEmpty) 'order_id': n.orderId!,
      'created_at': n.createdAt.toUtc().toIso8601String(),
    };

    await NotificationTapNavigator.handlePushData(
      Navigator.of(context),
      data: data,
      titleFallback: n.title,
      bodyFallback: n.message,
      createdAt: n.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);
    final wishlistCount = ref.watch(wishlistProvider).length;
    final cart = ref.watch(
      cartControllerProvider.select((async) => async.value),
    );
    final cartItemCount = cart?.items.fold<int>(0, (sum, e) => sum + e.quantity) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
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
      body: notificationsAsync.when(
        data: (listState) {
          if (listState.notifications.isEmpty) {
            return PageRefreshableBody(
              onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
              child: const PageEmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No notifications yet',
                subtitle: 'Order updates and promotions will show up here.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 10, bottom: 24),
              itemCount: listState.notifications.length +
                  (listState.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= listState.notifications.length) {
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

                final n = listState.notifications[index];
                return _NotificationListTile(
                  key: ValueKey<String>(n.id),
                  notification: n,
                  onTap: () => unawaited(_openNotificationTarget(n)),
                );
              },
            ),
          );
        },
        loading: () => const PageLoading(message: 'Loading notifications...'),
        error: (error, _) => PageRefreshableBody(
          onRefresh: () => ref.read(notificationsControllerProvider.notifier).refresh(),
          child: PageErrorState(
            title: 'Could not load notifications',
            message: 'Try signing in again.\n${error.toString()}',
          ),
        ),
      ),
    );
  }
}

class _NotificationListTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationListTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  String _formatTimeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return '${d.inDays} day(s) ago';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUnread = !notification.isRead;

    final bg = isUnread
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.14),
            scheme.surface,
          )
        : scheme.surfaceContainerHighest.withValues(alpha: 0.65);

    final borderSide = isUnread
        ? BorderSide(
            color: scheme.primary.withValues(alpha: 0.45),
            width: 1.2,
          )
        : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: borderSide,
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
                        color: isUnread
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.72),
                      ),
                ),
              ),
              if (isUnread)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.circle,
                    size: 10,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(
                        alpha: isUnread ? 0.95 : 0.72,
                      ),
                    ),
              ),
              if (notification.imageUrl != null &&
                  notification.imageUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                AppNetworkImage(
                  imageUrl: notification.imageUrl!.trim(),
                  width: double.infinity,
                  height: 110,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ],
          ),
          trailing: Text(
            _formatTimeAgo(notification.createdAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(
                    alpha: isUnread ? 0.9 : 0.65,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

