import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_env.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_message_router.dart';
import 'core/web/web_url_strategy_stub.dart'
    if (dart.library.html) 'core/web/web_url_strategy_web.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolates still need Firebase init.
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureWebUrlStrategy();
  final env = AppEnv.fromEnvironment();

  await Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
  );

  // FCM + local notifications are mobile-only. For Firebase on web (Analytics, etc.),
  // add a Web app in the Firebase console and run: dart run flutterfire_cli:flutterfire configure
  if (!kIsWeb) {
    await Firebase.initializeApp();
    await LocalNotificationService.initialize();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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
  }

  runApp(
    const ProviderScope(
      child: EcommerceApp(),
    ),
  );
}

