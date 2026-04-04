// Values from android/app/google-services.json (project anjanam-app).
// Use the same Firebase/GCP project for Supabase Edge secret GOOGLE_SERVICE_ACCOUNT_JSON_BASE64
// or FCM will not reach this app.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web — FCM is disabled on web in this app.',
      );
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
}
