import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/auth/state/auth_session_provider.dart';
import 'package:ecommerce_app/features/notifications/state/app_notification.dart';

final notificationsControllerProvider = AsyncNotifierProvider<
    NotificationsController, NotificationsListState>(
  NotificationsController.new,
);

class NotificationsListState {
  final List<AppNotification> notifications;
  final bool hasMore;
  final bool isLoadingMore;

  const NotificationsListState({
    required this.notifications,
    required this.hasMore,
    this.isLoadingMore = false,
  });
}

class NotificationsController extends AsyncNotifier<NotificationsListState> {
  static const int _pageSize = 20;

  SupabaseClient get _client => ref.read(supabaseClientProvider);

  /// PostgREST may return timestamptz as ISO [String], [DateTime], or epoch [num].
  static DateTime? _parseNullableInstant(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    return parsed?.toUtc();
  }

  static DateTime _parseInstant(dynamic value, {DateTime? fallback}) {
    return _parseNullableInstant(value) ?? fallback ?? DateTime.now().toUtc();
  }

  Future<({List<AppNotification> items, bool hasMore})> _fetchPage({
    required String authUserId,
    required int limit,
    required int offset,
  }) async {
    // Use `limit + 1` to detect pagination without a separate COUNT query.
    final take = limit + 1;
    final end = offset + take - 1;

    List<Map<String, dynamic>> rows;
    try {
      final data = await _client
          .from('user_notifications')
          .select(
            'id,title,body,kind,order_id,redirect_type,redirect_value,image_url,read_at,created_at',
          )
          .eq('user_id', authUserId.trim().toLowerCase())
          .order('created_at', ascending: false)
          .range(offset, end);
      rows = (data as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // Fallback for older schemas without redirect metadata.
      final data = await _client
          .from('user_notifications')
          .select('id,title,body,kind,order_id,read_at,created_at')
          .eq('user_id', authUserId.trim().toLowerCase())
          .order('created_at', ascending: false)
          .range(offset, end);
      rows = (data as List).cast<Map<String, dynamic>>();
    }

    final hasMore = rows.length > limit;
    final slice = hasMore ? rows.sublist(0, limit) : rows;

    final items = slice.map((r) {
      final createdAt = _parseInstant(
        r['created_at'],
        fallback: DateTime.now().toUtc(),
      );

      final readAt = _parseNullableInstant(r['read_at']);

      return AppNotification(
        id: (r['id'] ?? '').toString(),
        title: (r['title'] ?? '').toString(),
        message: (r['body'] ?? '').toString(),
        kind: (r['kind'] ?? 'notification').toString(),
        redirectType: r['redirect_type']?.toString(),
        redirectValue: r['redirect_value']?.toString(),
        orderId: r['order_id']?.toString(),
        imageUrl: r['image_url']?.toString(),
        createdAt: createdAt,
        readAt: readAt,
      );
    }).toList();

    return (items: items, hasMore: hasMore);
  }

  Future<int> _fetchUnreadCountApprox({required String authUserId}) async {
    // Best-effort count. We avoid a NULL-filter dependency on PostgREST
    // operators by fetching a small recent window.
    final rows = await _client
        .from('user_notifications')
        .select('id,read_at')
        .eq('user_id', authUserId.trim().toLowerCase())
        .order('created_at', ascending: false)
        .range(0, 199);

    final list = (rows as List).cast<Map<String, dynamic>>();
    var unread = 0;
    for (final r in list) {
      if (_parseNullableInstant(r['read_at']) == null) unread += 1;
    }
    return unread;
  }

  @override
  Future<NotificationsListState> build() async {
    final auth = ref.watch(authSessionProvider);
    if (auth.isLoading) {
      return const NotificationsListState(notifications: [], hasMore: false);
    }
    final authUser = auth.value;
    if (authUser == null) {
      return const NotificationsListState(notifications: [], hasMore: false);
    }

    final page = await _fetchPage(
      authUserId: authUser.idForSupabase,
      limit: _pageSize,
      offset: 0,
    );

    return NotificationsListState(
      notifications: page.items,
      hasMore: page.hasMore,
    );
  }

  Future<void> refresh() async {
    final auth = ref.read(authSessionProvider);
    final authUser = auth.value;
    if (authUser == null) {
      state = const AsyncValue.data(
        NotificationsListState(notifications: [], hasMore: false),
      );
      return;
    }

    final page = await _fetchPage(
      authUserId: authUser.idForSupabase,
      limit: _pageSize,
      offset: 0,
    );
    state = AsyncValue.data(
      NotificationsListState(notifications: page.items, hasMore: page.hasMore),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final auth = ref.read(authSessionProvider);
    final authUser = auth.value;
    if (authUser == null) return;

    state = AsyncValue.data(
      NotificationsListState(
        notifications: current.notifications,
        hasMore: current.hasMore,
        isLoadingMore: true,
      ),
    );

    try {
      final page = await _fetchPage(
        authUserId: authUser.idForSupabase,
        limit: _pageSize,
        offset: current.notifications.length,
      );
      state = AsyncValue.data(
        NotificationsListState(
          notifications: [...current.notifications, ...page.items],
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(
        NotificationsListState(
          notifications: current.notifications,
          hasMore: current.hasMore,
          isLoadingMore: false,
        ),
      );
    }
  }

  void _optimisticallyMarkRead(String notificationId) {
    final cur = state.value;
    if (cur == null) return;
    final now = DateTime.now().toUtc();
    var changed = false;
    final next = cur.notifications.map((n) {
      if (n.id != notificationId) return n;
      if (n.isRead) return n;
      changed = true;
      return n.copyWith(readAt: now);
    }).toList();
    if (!changed) return;
    state = AsyncValue.data(
      NotificationsListState(
        notifications: next,
        hasMore: cur.hasMore,
        isLoadingMore: cur.isLoadingMore,
      ),
    );
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    final auth = ref.read(authSessionProvider).value;
    if (auth == null) return;

    _optimisticallyMarkRead(notificationId);

    try {
      await _client.from('user_notifications').update({
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', notificationId);
    } catch (_) {
      await refresh();
      ref.invalidate(unreadNotificationsCountProvider);
      return;
    }
    // Reconcile with server; invalidate badge after DB write so count isn’t stale.
    await refresh();
    ref.invalidate(unreadNotificationsCountProvider);
  }

  Future<int> unreadCountApprox() async {
    final auth = ref.read(authSessionProvider).value;
    if (auth == null) return 0;
    return _fetchUnreadCountApprox(authUserId: auth.idForSupabase);
  }
}

/// Widget-friendly unread count (badge).
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  // If still loading auth, show nothing until resolved.
  final auth = ref.watch(authSessionProvider);
  final user = auth.value;
  if (user == null) return 0;
  return ref.read(notificationsControllerProvider.notifier).unreadCountApprox();
});

