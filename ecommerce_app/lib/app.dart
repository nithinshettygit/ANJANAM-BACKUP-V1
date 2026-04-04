import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/notifications/notification_message_router.dart';
import 'core/notifications/notification_navigation.dart';
import 'features/catalog/state/product_list_providers.dart';
import 'features/auth/state/auth_session_provider.dart';
import 'features/notifications/data/services/supabase_device_token_service.dart';
import 'features/notifications/state/notifications_controller.dart';
import 'presentation/routing/app_router.dart';

class EcommerceApp extends ConsumerStatefulWidget {
  const EcommerceApp({super.key});

  @override
  ConsumerState<EcommerceApp> createState() => _EcommerceAppState();
}

class _EcommerceAppState extends ConsumerState<EcommerceApp>
    with WidgetsBindingObserver {
  bool _wasPaused = false;
  bool _fcmBootstrapped = false;
  String? _fcmToken;
  bool _authListenAttached = false;
  RealtimeChannel? _notificationsChannel;
  String? _notificationsChannelUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    NotificationMessageRouter.onNotificationsChanged = _refreshNotificationUi;

    // Handle FCM taps when the app was previously closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationMessageRouter.onInitialMessageIfAny());
    });

    // Bootstrap FCM + store token in Supabase (best-effort).
    unawaited(_bootstrapFcmAndToken());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authListenAttached) return;
    _authListenAttached = true;

    // Sync FCM token whenever user signs in.
    ref.listenManual<AsyncValue<dynamic>>(authSessionProvider, (previous, next) {
      final user = next.asData?.value;
      if (user == null) {
        _stopNotificationsRealtime();
        return;
      }
      _startNotificationsRealtime(user.id);
      final token = _fcmToken;
      if (token == null || token.isEmpty) return;

      unawaited(
        _saveDeviceTokenToSupabase(
          userId: user.id,
          token: token,
        ),
      );
    });
  }

  @override
  void dispose() {
    _stopNotificationsRealtime();
    NotificationMessageRouter.onNotificationsChanged = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    } else if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      ref.read(storefrontCatalogRevisionProvider.notifier).bump();
      _refreshNotificationUi();
    }
  }

  void _refreshNotificationUi() {
    ref.invalidate(unreadNotificationsCountProvider);
    // Refetch list in place (avoids full provider dispose + loading flash).
    unawaited(
      ref.read(notificationsControllerProvider.notifier).refresh(),
    );
  }

  void _startNotificationsRealtime(String userId) {
    if (_notificationsChannelUserId == userId && _notificationsChannel != null) {
      return;
    }
    _stopNotificationsRealtime();

    final channel = Supabase.instance.client.channel('user-notifications-$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) {
          _refreshNotificationUi();
        },
      )
      ..subscribe();

    _notificationsChannel = channel;
    _notificationsChannelUserId = userId;
  }

  void _stopNotificationsRealtime() {
    final channel = _notificationsChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _notificationsChannel = null;
    _notificationsChannelUserId = null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kIsWeb ? 'ANJANAM Admin' : 'ANJANAM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      navigatorKey: notificationNavigatorKey,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }

  Future<void> _bootstrapFcmAndToken() async {
    if (_fcmBootstrapped) return;
    _fcmBootstrapped = true;
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    const permissionKey = 'fcm_permission_requested';

    try {
      final alreadyRequested = prefs.getBool(permissionKey) ?? false;
      if (!alreadyRequested) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await prefs.setBool(permissionKey, true);
      }
    } catch (_) {
      // Permission failures should not break app startup.
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      _fcmToken = token;
    } catch (_) {
      _fcmToken = null;
    }

    // Token refresh: keep DB updated.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      final user = ref.read(authSessionProvider).asData?.value;
      if (user == null) return;
      unawaited(
        _saveDeviceTokenToSupabase(
          userId: user.id,
          token: newToken,
        ),
      );
    });

    // If user is already logged in, persist immediately.
    try {
      final user = ref.read(authSessionProvider).asData?.value;
      if (user != null && _fcmToken != null && _fcmToken!.isNotEmpty) {
        await _saveDeviceTokenToSupabase(userId: user.id, token: _fcmToken!);
      }
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _saveDeviceTokenToSupabase({
    required String userId,
    required String token,
  }) async {
    final deviceType = _deviceTypeForThisPlatform();
    final service = SupabaseDeviceTokenService(
      // Uses the global Supabase singleton already initialized in `main.dart`.
      Supabase.instance.client,
    );
    await service.upsertDeviceToken(
      userId: userId,
      fcmToken: token,
      deviceType: deviceType,
    );
  }

  String _deviceTypeForThisPlatform() {
    // This app is currently Android-first; keep it resilient.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }
}

