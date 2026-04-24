import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../presentation/pages/notification_detail_page.dart';
import '../../presentation/widgets/product_image_fullscreen_gallery.dart';

/// Central routing when a user opens a notification (FCM tap or in-app list).
class NotificationTapNavigator {
  NotificationTapNavigator._();

  static const List<String> _urlDataKeys = <String>[
    'url',
    'link',
    'deep_link_url',
    'redirect_url',
    'target_url',
    'cta_url',
    'web_url',
    'redirect_value',
  ];

  static const List<String> _imageDataKeys = <String>[
    'image_url',
    'image',
    'imageUrl',
    'banner_url',
    'media_url',
  ];

  static void _pushDetail(
    NavigatorState nav, {
    required String notificationId,
    required String title,
    required String message,
    DateTime? createdAt,
    String? kindLabel,
    String? imageUrl,
  }) {
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailPage(
          notificationId: notificationId,
          title: title,
          message: message,
          createdAt: createdAt,
          kindLabel: kindLabel,
          imageUrl: imageUrl,
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
    final imageUrl = data['image_url']?.toString().trim();
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

    final tapUrl = _firstHttpUrl(data, _urlDataKeys);
    if (tapUrl != null) {
      final opened = await _openExternalUrl(tapUrl);
      if (opened) return;
    }

    final tapImageUrl = _firstHttpUrl(data, _imageDataKeys);
    if (tapImageUrl != null) {
      final opened = await _openImageViewer(nav, tapImageUrl);
      if (opened) return;
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
          imageUrl: imageUrl,
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
        imageUrl: imageUrl,
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

  static String? _firstHttpUrl(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key]?.toString().trim();
      if (raw == null || raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        return uri.toString();
      }
    }
    return null;
  }

  static Future<bool> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _openImageViewer(NavigatorState nav, String imageUrl) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }
    await nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ProductImageFullscreenGallery(imageUrls: <String>[imageUrl]),
      ),
    );
    return true;
  }
}
