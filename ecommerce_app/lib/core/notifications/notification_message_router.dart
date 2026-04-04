import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_service.dart';
import 'notification_navigation.dart';
import 'notification_tap_navigator.dart';

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

    final nav = notificationNavigatorKey.currentState;
    final title = message.notification?.title;
    final body = message.notification?.body;
    await NotificationTapNavigator.handlePushData(
      nav,
      data: Map<String, dynamic>.from(message.data),
      titleFallback: title,
      bodyFallback: body,
    );
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

