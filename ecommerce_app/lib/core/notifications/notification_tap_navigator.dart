import 'package:flutter/material.dart';

import '../../presentation/pages/notification_detail_page.dart';

/// Central routing when a user opens a notification (FCM tap or in-app list).
class NotificationTapNavigator {
  NotificationTapNavigator._();

  static void _pushDetail(
    NavigatorState nav, {
    required String notificationId,
    required String title,
    required String message,
    DateTime? createdAt,
    String? kindLabel,
  }) {
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailPage(
          notificationId: notificationId,
          title: title,
          message: message,
          createdAt: createdAt,
          kindLabel: kindLabel,
        ),
      ),
    );
  }

  /// [data] is FCM `message.data` (all string values).
  static Future<void> handlePushData(
    NavigatorState? nav, {
    required Map<String, dynamic> data,
    String? titleFallback,
    String? bodyFallback,
    DateTime? createdAt,
  }) async {
    if (nav == null) return;

    DateTime? resolvedCreated = createdAt;
    if (resolvedCreated == null) {
      final raw = data['created_at']?.toString().trim();
      if (raw != null && raw.isNotEmpty) {
        resolvedCreated = DateTime.tryParse(raw)?.toUtc();
      }
    }

    final redirectType = data['redirect_type']?.toString().trim().toLowerCase();
    final redirectValue = data['redirect_value']?.toString().trim();
    final orderId = data['order_id']?.toString().trim();
    final kind = data['kind']?.toString().trim().toLowerCase();
    final notificationId = data['notification_id']?.toString().trim() ?? '';
    final title = (data['title']?.toString().trim().isNotEmpty == true)
        ? data['title'].toString()
        : (titleFallback ?? 'Notification');
    final message = (data['message']?.toString().trim().isNotEmpty == true)
        ? data['message'].toString()
        : (bodyFallback ?? '');

    final resolvedRedirect = (redirectType == null || redirectType.isEmpty)
        ? (orderId != null && orderId.isNotEmpty ? 'order' : 'none')
        : redirectType;

    if (resolvedRedirect == 'order' && orderId != null && orderId.isNotEmpty) {
      nav.pushNamed('/order-details', arguments: orderId);
      return;
    }

    if (resolvedRedirect == 'product' &&
        redirectValue != null &&
        redirectValue.isNotEmpty) {
      nav.pushNamed('/catalog/details', arguments: redirectValue);
      return;
    }

    if (resolvedRedirect == 'category' &&
        redirectValue != null &&
        redirectValue.isNotEmpty) {
      nav.pushNamed('/products?category=$redirectValue');
      return;
    }

    if (_isHomeCatalogRedirect(resolvedRedirect)) {
      nav.pushNamed('/catalog/browse', arguments: {'mode': resolvedRedirect});
      return;
    }

    if (resolvedRedirect == 'catalog_browse') {
      nav.pushNamed('/catalog/browse', arguments: const {'mode': 'all'});
      return;
    }

    final screenRoute = _screenRouteForRedirect(resolvedRedirect);
    if (screenRoute != null) {
      nav.pushNamed(screenRoute);
      return;
    }

    if (resolvedRedirect == 'none' || resolvedRedirect.isEmpty) {
      if (notificationId.isNotEmpty) {
        _pushDetail(
          nav,
          notificationId: notificationId,
          title: title,
          message: message,
          createdAt: resolvedCreated,
          kindLabel: _kindDisplayLabel(kind),
        );
      } else {
        nav.pushNamed('/notifications');
      }
      return;
    }

    if (kind == 'order_status' && orderId != null && orderId.isNotEmpty) {
      nav.pushNamed('/order-details', arguments: orderId);
      return;
    }

    if (notificationId.isNotEmpty) {
      _pushDetail(
        nav,
        notificationId: notificationId,
        title: title,
        message: message,
        createdAt: resolvedCreated,
        kindLabel: _kindDisplayLabel(kind),
      );
    } else {
      nav.pushNamed('/notifications');
    }
  }

  static bool _isHomeCatalogRedirect(String? t) {
    return t == 'home_popular' ||
        t == 'home_recommended' ||
        t == 'home_festival' ||
        t == 'home_new_arrivals';
  }

  static String? _screenRouteForRedirect(String? t) {
    switch (t) {
      case 'screen_books':
        return '/books';
      case 'screen_videos':
        return '/videos';
      case 'screen_music':
        return '/music';
      case 'screen_wishlist':
        return '/wishlist';
      case 'screen_cart':
        return '/cart';
      case 'screen_orders':
        return '/orders';
      case 'screen_search':
        return '/search';
      case 'screen_profile':
        return '/profile';
      case 'screen_more':
        return '/more';
      default:
        return null;
    }
  }

  static String? _kindDisplayLabel(String? kind) {
    switch (kind) {
      case 'promotion':
        return 'Promotion';
      case 'announcement':
        return 'Announcement';
      case 'order_status':
        return 'Order update';
      default:
        return null;
    }
  }
}
