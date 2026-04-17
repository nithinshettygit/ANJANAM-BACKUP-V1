import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_email_link_navigation.dart';
import 'core/config/auth_redirect_config.dart';
import 'core/config/storefront_app_link.dart';
import 'features/articles/providers/articles_providers.dart';
import 'features/product_details/state/product_details_providers.dart';
import 'features/videos/providers/videos_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_message_router.dart';
import 'core/notifications/notification_navigation.dart';
import 'features/catalog/state/product_list_providers.dart';
import 'features/auth/domain/entities/app_user.dart';
import 'features/auth/state/auth_session_provider.dart';
import 'features/notifications/data/services/supabase_device_token_service.dart';
import 'features/notifications/state/notifications_controller.dart';
import 'presentation/routing/app_router.dart';

/// Web cold-load: use the browser path (e.g. /product/<id>) instead of defaulting to / only.
List<Route<dynamic>> _webGenerateInitialRoutes(String _) {
  var path = Uri.base.path;
  if (path.isEmpty) path = '/';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return [AppRouter.onGenerateRoute(RouteSettings(name: path))];
}

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
  StreamSubscription<AuthState>? _passwordRecoverySub;
  StreamSubscription<Uri?>? _appLinkSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;

  void _navigateToAuthEmailLink(AuthEmailLinkKind kind) {
    final route = materialRouteForAuthEmailLink(kind);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = notificationNavigatorKey.currentState;
      if (nav == null || !nav.mounted) return;
      nav.pushNamedAndRemoveUntil(route, (_) => false);
    });
  }

  void _navigateToSharedProduct(String productId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = notificationNavigatorKey.currentState;
      if (nav == null || !nav.mounted) return;
      ref.invalidate(productDetailsProvider(productId));
      nav.pushNamed('/catalog/details', arguments: productId);
    });
  }

  void _navigateToSharedVideo(String videoId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = notificationNavigatorKey.currentState;
      if (nav == null || !nav.mounted) return;
      ref.invalidate(videoByIdProvider(videoId));
      nav.pushNamed('/video/$videoId');
    });
  }

  void _navigateToSharedArticle(String articleId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = notificationNavigatorKey.currentState;
      if (nav == null || !nav.mounted) return;
      ref.invalidate(articleByIdProvider(articleId));
      nav.pushNamed('/article/$articleId');
    });
  }

  void _listenAndroidAppLinks() {
    if (kIsWeb) return;
    final appLinks = AppLinks();
    void handleUri(Uri? uri) {
      if (uri == null) return;
      final authKind = classifyAuthEmailLink(uri);
      if (authKind != null) {
        _navigateToAuthEmailLink(authKind);
        return;
      }
      final productId = StorefrontAppLink.productIdIfValid(uri);
      if (productId != null) {
        _navigateToSharedProduct(productId);
        return;
      }
      final videoId = StorefrontAppLink.videoIdIfValid(uri);
      if (videoId != null) {
        _navigateToSharedVideo(videoId);
        return;
      }
      final articleId = StorefrontAppLink.articleIdIfValid(uri);
      if (articleId != null) {
        _navigateToSharedArticle(articleId);
      }
    }

    _appLinkSub = appLinks.uriLinkStream.listen(handleUri);
    unawaited(appLinks.getInitialLink().then(handleUri));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivityIndicator();

    _listenAndroidAppLinks();

    _passwordRecoverySub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event != AuthChangeEvent.passwordRecovery) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = notificationNavigatorKey.currentState;
        if (nav == null || !nav.mounted) return;
        nav.pushNamedAndRemoveUntil(
          AuthRedirectConfig.webAuthPasswordResetPath,
          (route) => false,
        );
      });
    });

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
    ref.listenManual<AsyncValue<AppUser?>>(authSessionProvider, (previous, next) {
      final user = next.asData?.value;
      if (user == null) {
        _stopNotificationsRealtime();
        return;
      }
      _startNotificationsRealtime(user.idForSupabase);
      final token = _fcmToken;
      if (token == null || token.isEmpty) return;

      unawaited(
        _saveDeviceTokenToSupabase(
          userId: user.idForSupabase,
          token: token,
        ),
      );
    });
  }

  @override
  void dispose() {
    _appLinkSub?.cancel();
    _connectivitySub?.cancel();
    _passwordRecoverySub?.cancel();
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
      title: kIsWeb ? 'ANJANAM' : 'ANJANAM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      navigatorKey: notificationNavigatorKey,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onGenerateInitialRoutes: kIsWeb ? _webGenerateInitialRoutes : null,
      builder: (context, child) {
        final body = child ?? const SizedBox.shrink();
        if (!_isOffline) return body;
        return Stack(
          children: [
            body,
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.paddingOf(context).top + 8,
              child: _OfflineBanner(onRetry: _checkConnectivityNow),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkConnectivityNow() async {
    final connectivity = Connectivity();
    try {
      final current = await connectivity.checkConnectivity();
      final offline = !current.any((r) => r != ConnectivityResult.none);
      if (!mounted) return;
      if (_isOffline != offline) {
        setState(() => _isOffline = offline);
      }
    } catch (_) {}
  }

  Future<void> _initConnectivityIndicator() async {
    final connectivity = Connectivity();

    Future<void> setFromResults(List<ConnectivityResult> results) async {
      final offline = !results.any((r) => r != ConnectivityResult.none);
      if (!mounted || offline == _isOffline) return;
      setState(() => _isOffline = offline);
    }

    try {
      final current = await connectivity.checkConnectivity();
      await setFromResults(current);
    } catch (_) {}

    _connectivitySub = connectivity.onConnectivityChanged.listen((results) {
      // ignore: discarded_futures
      setFromResults(results);
    });
  }

  Future<void> _bootstrapFcmAndToken() async {
    if (_fcmBootstrapped) return;
    _fcmBootstrapped = true;
    if (kIsWeb) return;
    try {
      Firebase.app();
    } catch (_) {
      // In tests or misconfigured environments, Firebase may be unavailable.
      // Skip FCM bootstrap instead of crashing app startup.
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      final auth = settings.authorizationStatus;
      if (auth == AuthorizationStatus.notDetermined ||
          auth == AuthorizationStatus.denied ||
          auth == AuthorizationStatus.provisional) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {
      // Permission failures should not break app startup.
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      _fcmToken = token;
      if (kDebugMode && (token == null || token.isEmpty)) {
        debugPrint(
          'FCM: getToken() is empty. Notifications cannot work until Firebase returns a token.',
        );
      }
    } catch (_) {
      _fcmToken = null;
    }

    // Token refresh: keep DB updated.
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        final user = ref.read(authSessionProvider).asData?.value;
        if (user == null) return;
        unawaited(
          _saveDeviceTokenToSupabase(
            userId: user.idForSupabase,
            token: newToken,
          ),
        );
      });
    } catch (_) {
      // Best-effort only.
    }

    // If user is already logged in, persist immediately.
    try {
      final user = ref.read(authSessionProvider).asData?.value;
      if (user != null && _fcmToken != null && _fcmToken!.isNotEmpty) {
        await _saveDeviceTokenToSupabase(userId: user.idForSupabase, token: _fcmToken!);
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

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFD84315), Color(0xFFB71C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No internet connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Some features may be unavailable until connection is restored.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFFDECEC),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(64, 34),
                backgroundColor: Colors.white.withOpacity(0.95),
                foregroundColor: scheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

