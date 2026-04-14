// Values from android/app/google-services.json (project anjanam-app).
// Use the same Firebase/GCP project for Supabase Edge secret GOOGLE_SERVICE_ACCOUNT_JSON_BASE64
// or FCM will not reach this app.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      final opts = _webFromDartDefines();
      if (opts != null) return opts;
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBcR88EY2Y4fKyWyb6MtSUsKt9EhDlF_aA',
    appId: '1:464689472535:android:7b1bf15781e4495105a852',
    messagingSenderId: '464689472535',
    projectId: 'anjanam-app',
    storageBucket: 'anjanam-app.firebasestorage.app',
  );

  static FirebaseOptions? _webFromDartDefines() {
    const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const messagingSenderId = String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
    const authDomainFromDefine = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');
    const measurementId = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');

    if (apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty || projectId.isEmpty) {
      return null;
    }

    final authDomain = authDomainFromDefine.isNotEmpty
        ? authDomainFromDefine
        : '$projectId.firebaseapp.com';

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }

  // Production fallback for hosted web builds where dart-defines may be omitted.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBgdR_rS545EsIRWDPY2djHQNI3q5EV8ew',
    appId: '1:464689472535:web:483c9581b7a07f9205a852',
    messagingSenderId: '464689472535',
    projectId: 'anjanam-app',
    authDomain: 'anjanam-app.firebaseapp.com',
    storageBucket: 'anjanam-app.firebasestorage.app',
    measurementId: 'G-C7FLSTTP2L',
  );
}
