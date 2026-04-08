import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_env.dart';
import 'core/config/web_hosted_app_config.dart';
import 'core/notifications/local_notification_service.dart';
import 'firebase_options.dart';
import 'core/notifications/notification_message_router.dart';
import 'core/web/web_url_strategy_stub.dart'
    if (dart.library.html) 'core/web/web_url_strategy_web.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.initialize();
  // Background/system messages with only `data` payload do not always appear in tray.
  // Show a local notification fallback so order/refund updates still reach notification bar.
  if (message.notification == null) {
    final title = message.data['title']?.toString().trim().isNotEmpty == true
        ? message.data['title'].toString().trim()
        : 'Notification';
    final body = message.data['message']?.toString().trim() ?? '';
    final dedupKey = [
      message.data['notification_id']?.toString().trim(),
      message.data['kind']?.toString().trim(),
      message.data['order_id']?.toString().trim(),
      title,
      body,
    ].where((e) => e != null && e.isNotEmpty).join('|');
    await LocalNotificationService.show(
      title: title,
      body: body,
      payload: message.data.toString(),
      dedupKey: dedupKey.isEmpty ? null : dedupKey,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureWebUrlStrategy();

  if (kIsWeb) {
    await _runWebApp();
  } else {
    await _runMobileApp();
  }
}

Future<void> _runWebApp() async {
  try {
    late final AppEnv env;
    try {
      env = AppEnv.fromEnvironment();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Web: no compile-time Supabase defines, trying /app-config.json … ($e)');
      }
      final fromHost = await tryLoadWebHostedAppConfig();
      if (fromHost == null) rethrow;
      env = fromHost;
    }
    registerAppEnv(env);
    await Supabase.initialize(
      url: env.supabaseUrl,
      anonKey: env.supabaseAnonKey,
    );
    runApp(
      const ProviderScope(
        child: EcommerceApp(),
      ),
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Web startup error: $e');
      debugPrint('$st');
    }
    runApp(_WebConfigErrorApp(message: e.toString()));
  }
}

Future<void> _runMobileApp() async {
  try {
    final env = AppEnv.fromEnvironment();
    registerAppEnv(env);

    await Supabase.initialize(
      url: env.supabaseUrl,
      anonKey: env.supabaseAnonKey,
    );

    // FCM + local notifications are mobile-only. For Firebase on web (Analytics, etc.),
    // add a Web app in the Firebase console and run: dart run flutterfire_cli:flutterfire configure
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await LocalNotificationService.initialize();
    FirebaseMessaging.onMessage.listen((message) {
      NotificationMessageRouter.onMessage(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationMessageRouter.onNotificationTap(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      NotificationMessageRouter.setPendingInitialMessage(initialMessage);
    }

    runApp(
      const ProviderScope(
        child: EcommerceApp(),
      ),
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Mobile startup error: $e');
      debugPrint('$st');
    }
    runApp(_MobileStartupErrorApp(message: e.toString()));
  }
}

/// Shown when the Android/iOS build omitted compile-time Supabase defines or startup failed.
class _MobileStartupErrorApp extends StatelessWidget {
  const _MobileStartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANJANAM — configuration',
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App could not start',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Release and debug APKs need Supabase baked in at build time. '
                    'Fill tool/web_build.env (see tool/web_build.env.example), then run '
                    'scripts\\build_android_release.ps1 — or pass '
                    '--dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=... '
                    'to flutter build apk.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.redAccent,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when web was built without SUPABASE_URL / SUPABASE_ANON_KEY (or other startup failure).
class _WebConfigErrorApp extends StatelessWidget {
  const _WebConfigErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANJANAM — configuration',
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Web app could not start',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Fix options: (1) Build with Supabase baked in — copy tool/web_build.env.example '
                    'to tool/web_build.env, add your keys, then run scripts\\build_admin_web.ps1. '
                    '(2) Or deploy web/app-config.json at the site root (copy from web/app-config.json.example) '
                    'so the app can load config at runtime (still need to redeploy hosting). '
                    '(3) Supabase init failed — check URL/key. '
                    '(4) Clear site data or a private window if a service worker cached a broken bundle.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'scripts\\build_admin_web.ps1  ·  web/app-config.json',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13, color: Colors.redAccent, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

