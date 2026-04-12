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
    final type = data['type']?.toString().trim().toLowerCase();
    final referenceId = data['reference_id']?.toString().trim();
    final adminNotificationId = data['admin_notification_id']?.toString().trim();
    final notificationId = data['notification_id']?.toString().trim() ?? '';
    final resolvedRedirect = (redirectType == null || redirectType.isEmpty)
        ? (orderId != null && orderId.isNotEmpty ? 'order' : 'none')
        : redirectType;
    if ((kind == 'admin_notification' || resolvedRedirect == 'admin_notification') &&
        adminNotificationId != null &&
        adminNotificationId.isNotEmpty) {
      _openAdminTarget(nav, type: type, referenceId: referenceId);
      return;
    }

    final title = (data['title']?.toString().trim().isNotEmpty == true)
        ? data['title'].toString()
        : (titleFallback ?? 'Notification');
    final message = (data['message']?.toString().trim().isNotEmpty == true)
        ? data['message'].toString()
        : (bodyFallback ?? '');

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

  static void _openAdminTarget(
    NavigatorState nav, {
    required String? type,
    required String? referenceId,
  }) {
    switch (type) {
      case 'order_created':
        if (referenceId != null && referenceId.isNotEmpty) {
          nav.pushNamed('/admin/orders/details/$referenceId');
        } else {
          nav.pushNamed('/admin/orders');
        }
        return;
      case 'new_user':
        if (referenceId != null && referenceId.isNotEmpty) {
          nav.pushNamed('/admin/users/details/$referenceId');
        } else {
          nav.pushNamed('/admin/users');
        }
        return;
      case 'product_review':
        nav.pushNamed('/admin/product-reviews');
        return;
      case 'product_question':
        nav.pushNamed('/admin/product-questions');
        return;
      case 'return_request':
      case 'refund_request':
        nav.pushNamed('/admin/returns');
        return;
      case 'low_stock':
      case 'out_of_stock':
        nav.pushNamed('/admin/inventory');
        return;
      default:
        nav.pushNamed('/admin/admin-notifications');
        return;
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
