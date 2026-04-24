import 'dart:convert';

import 'package:ecommerce_app/core/network/http_resilience.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ecommerce_app/core/notifications/notification_markdown_text.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription =
      'Used for order updates and important alerts.';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static final Map<String, DateTime> _recentDedupKeys = <String, DateTime>{};
  static Future<void> Function(Map<String, dynamic> data)? _onTapData;

  static void setOnTapHandler(Future<void> Function(Map<String, dynamic> data)? handler) {
    _onTapData = handler;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) async {
        final raw = response.payload?.trim();
        if (raw == null || raw.isEmpty) return;
        Map<String, dynamic> payload;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            payload = decoded;
          } else if (decoded is Map) {
            payload = Map<String, dynamic>.from(decoded);
          } else {
            return;
          }
        } catch (_) {
          return;
        }
        final handler = _onTapData;
        if (handler != null) {
          await handler(payload);
        }
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
    );

    // Android 13+: required to show heads-up / tray from foreground FCM handling.
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    if (!_initialized) {
      await initialize();
    }

    final title =
        message.notification?.title ?? message.data['title']?.toString() ?? 'Notification';
    final body =
        message.notification?.body ?? message.data['message']?.toString() ?? '';
    final displayTitle = stripNotificationMarkdownBold(title);
    final displayBody = stripNotificationMarkdownBold(body);
    final imageUrl =
        message.data['image_url']?.toString().trim().isNotEmpty == true
            ? message.data['image_url']!.toString().trim()
            : null;

    final androidDetails = await _androidDetailsForImage(
      title: displayTitle,
      body: displayBody,
      imageUrl: imageUrl,
    );

    final dedupKey = [
      message.data['notification_id']?.toString().trim(),
      message.data['kind']?.toString().trim(),
      message.data['order_id']?.toString().trim(),
      displayTitle,
      displayBody,
    ].where((e) => e != null && e.isNotEmpty).join('|');
    await show(
      title: displayTitle,
      body: displayBody,
      payload: jsonEncode(message.data),
      dedupKey: dedupKey.isEmpty ? null : dedupKey,
      androidDetails: androidDetails,
    );
  }

  static Future<AndroidNotificationDetails> _androidDetailsForImage({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    final image = await _tryFetchImageBitmap(imageUrl);
    if (image == null) {
      return const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
    }
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigPictureStyleInformation(
        image,
        contentTitle: title.trim(),
        summaryText: body.trim(),
        hideExpandedLargeIcon: true,
      ),
    );
  }

  static Future<ByteArrayAndroidBitmap?> _tryFetchImageBitmap(String? imageUrl) async {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;
    try {
      final res = await HttpResilience.get(uri, timeout: const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300 || res.bodyBytes.isEmpty) {
        return null;
      }
      return ByteArrayAndroidBitmap(res.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<void> show({
    required String title,
    required String body,
    String? payload,
    String? dedupKey,
    AndroidNotificationDetails? androidDetails,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final normalizedTitle = stripNotificationMarkdownBold(
      title.trim().isEmpty ? 'Notification' : title.trim(),
    );
    final normalizedBody = stripNotificationMarkdownBold(body.trim());
    final now = DateTime.now();
    if (dedupKey != null && dedupKey.trim().isNotEmpty) {
      final key = dedupKey.trim();
      final prev = _recentDedupKeys[key];
      if (prev != null && now.difference(prev).inSeconds < 4) {
        return;
      }
      _recentDedupKeys[key] = now;
      _recentDedupKeys.removeWhere((_, time) => now.difference(time).inMinutes > 2);
    }

    final details = androidDetails ??
        const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: normalizedTitle,
      body: normalizedBody,
      notificationDetails: NotificationDetails(android: details),
      payload: payload,
    );
  }
}
