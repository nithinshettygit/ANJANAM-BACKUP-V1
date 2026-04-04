import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_service.dart';
import 'notification_navigation.dart';

/// Routes incoming FCM messages into:
/// - foreground in-app banner
/// - navigation on tap (background/closed)
/// - best-effort "mark read" on open
class NotificationMessageRouter {
  NotificationMessageRouter._();

  static RemoteMessage? _pendingInitialMessage;
  static VoidCallback? onNotificationsChanged;

  static void setPendingInitialMessage(RemoteMessage message) {
    _pendingInitialMessage = message;
  }

  static RemoteMessage? consumePendingInitialMessage() {
    final m = _pendingInitialMessage;
    _pendingInitialMessage = null;
    return m;
  }

  static void onMessage(RemoteMessage message) {
    // Foreground Android messages do not show system notifications by default.
    // Show a local notification so behavior matches normal apps.
    unawaited(LocalNotificationService.showFromRemoteMessage(message));

    // Foreground: show an in-app banner via SnackBar.
    final ctx = notificationNavigatorKey.currentContext;
    if (ctx == null) return;

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Notification';
    final body = message.notification?.body ??
        message.data['message']?.toString() ??
        '';

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
          body.isEmpty ? title : '$title\n$body',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    onNotificationsChanged?.call();
  }

  static Future<void> onNotificationTap(RemoteMessage message) async {
    // Mark read (best-effort) before navigating.
    await _markAsReadFromMessage(message);
    onNotificationsChanged?.call();

    final data = message.data;
    final redirectTypeRaw = data['redirect_type']?.toString().trim().toLowerCase();
    final redirectValue = data['redirect_value']?.toString().trim();

    // Order notifications: fall back to order_id if redirect info missing.
    final orderId = data['order_id']?.toString().trim();
    final kind = data['kind']?.toString().trim().toLowerCase();

    final resolvedRedirectType = (redirectTypeRaw?.isEmpty ?? true)
        ? (orderId != null && orderId.isNotEmpty ? 'order' : 'none')
        : redirectTypeRaw!;

    if (resolvedRedirectType == 'order' && (orderId?.isNotEmpty ?? false)) {
      notificationNavigatorKey.currentState?.pushNamed(
        '/order-details',
        arguments: orderId,
      );
      return;
    }

    if (resolvedRedirectType == 'product') {
      // ProductDetailsPage expects '/catalog/details' with productId as argument.
      if (redirectValue == null || redirectValue.isEmpty) return;
      notificationNavigatorKey.currentState?.pushNamed(
        '/catalog/details',
        arguments: redirectValue,
      );
      return;
    }

    if (resolvedRedirectType == 'category') {
      // CatalogPage category-filtering uses `/products?category=<slug>`.
      if (redirectValue == null || redirectValue.isEmpty) return;
      notificationNavigatorKey.currentState?.pushNamed(
        '/products?category=$redirectValue',
      );
      return;
    }

    // Announcements and fallbacks open Notifications history.
    if (resolvedRedirectType == 'announcement' ||
        resolvedRedirectType == 'promotion' ||
        resolvedRedirectType == 'none') {
      notificationNavigatorKey.currentState?.pushNamed('/notifications');
      return;
    }

    // Unknown redirect types: try notifications page.
    if (kind == 'order_status' && (orderId?.isNotEmpty ?? false)) {
      notificationNavigatorKey.currentState?.pushNamed(
        '/order-details',
        arguments: orderId,
      );
      return;
    }

    notificationNavigatorKey.currentState?.pushNamed('/notifications');
  }

  static Future<void> onInitialMessageIfAny() async {
    final pending = consumePendingInitialMessage();
    if (pending == null) return;
    unawaited(onNotificationTap(pending));
  }

  static Future<void> _markAsReadFromMessage(RemoteMessage message) async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return;

      final data = message.data;
      final notificationId = data['notification_id']?.toString().trim();
      final orderId = data['order_id']?.toString().trim();
      final kind = data['kind']?.toString().trim();

      final now = DateTime.now().toUtc().toIso8601String();

      if (notificationId != null && notificationId.isNotEmpty) {
        await client
            .from('user_notifications')
            .update({'read_at': now})
            .eq('id', notificationId);
        return;
      }

      // Order-based best-effort marking:
      if (orderId != null && orderId.isNotEmpty) {
        // If we have kind, restrict to order status notifications.
        if (kind != null && kind.isNotEmpty) {
          await client
              .from('user_notifications')
              .update({'read_at': now})
              .eq('order_id', orderId)
              .eq('kind', kind);
        } else {
          // If kind is missing, mark all unread notifications for the order.
          await client
              .from('user_notifications')
              .update({'read_at': now})
              .eq('order_id', orderId);
        }
      }
    } catch (_) {
      // Notification read marking must never block navigation.
    }
  }
}

