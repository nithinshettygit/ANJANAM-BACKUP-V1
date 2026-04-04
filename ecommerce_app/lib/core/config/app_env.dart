import 'package:flutter/foundation.dart';

class AppEnv {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabaseFunctionsBaseUrl;
  /// Razorpay **Key Id** (publishable / test). Never put the secret key in the app.
  /// Pass at build time: `--dart-define=RAZORPAY_TEST_KEY=rzp_test_...`
  /// Must match the Key Id configured as `RAZORPAY_KEY_ID` for Edge Functions (same Razorpay account).
  final String razorpayTestKey;

  const AppEnv({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.supabaseFunctionsBaseUrl = '',
    this.razorpayTestKey = '',
  });

  /// Trims whitespace and strips stray trailing `\` often introduced when a PowerShell
  /// `flutter run` line accidentally ends with `\)` next to `--dart-define=...=$env:...`.
  static String _cleanDefine(String value) {
    var v = value.trim();
    while (v.endsWith(r'\')) {
      v = v.substring(0, v.length - 1).trim();
    }
    return v;
  }

  static AppEnv fromEnvironment() {
    const urlRaw = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const anonKeyRaw = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    const functionsBaseUrlRaw = String.fromEnvironment(
      'SUPABASE_FUNCTIONS_BASE_URL',
      defaultValue: '',
    );
    const razorpayKeyRaw = String.fromEnvironment(
      'RAZORPAY_TEST_KEY',
      defaultValue: '',
    );
    final url = _cleanDefine(urlRaw);
    final anonKey = _cleanDefine(anonKeyRaw);
    final functionsBaseUrl = _cleanDefine(functionsBaseUrlRaw);
    final razorpayTestKey = _cleanDefine(razorpayKeyRaw);

    if (url.isEmpty || anonKey.isEmpty) {
      throw FlutterError(
        'Missing Supabase config. Provide SUPABASE_URL and SUPABASE_ANON_KEY '
        'at build time (e.g. flutter run --dart-define=SUPABASE_URL=... '
        '--dart-define=SUPABASE_ANON_KEY=...).',
      );
    }

    return AppEnv(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      supabaseFunctionsBaseUrl: functionsBaseUrl,
      razorpayTestKey: razorpayTestKey,
    );
  }
}

