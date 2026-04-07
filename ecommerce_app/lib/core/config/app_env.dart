import 'package:flutter/foundation.dart';

import 'auth_redirect_config.dart';

AppEnv? _registeredAppEnv;

/// Set once from [main] after resolving Supabase config (compile-time or hosted JSON on web).
void registerAppEnv(AppEnv env) {
  _registeredAppEnv = env;
}

/// For tests only.
void clearRegisteredAppEnv() {
  _registeredAppEnv = null;
}

class AppEnv {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabaseFunctionsBaseUrl;

  /// Razorpay **Key Id** only (`rzp_live_...`). Never put the secret in the app.
  ///
  /// Build: `--dart-define=RAZORPAY_KEY_ID=...`.
  /// Must match Supabase secret `RAZORPAY_KEY_ID` for Edge Functions.
  final String razorpayKeyId;

  /// Optional override from `--dart-define=SUPABASE_AUTH_REDIRECT_URL=...`.
  /// If empty, [resolvedAuthEmailRedirectUrl] uses the web origin + [AuthRedirectConfig.webAuthCallbackPath]
  /// on web, or [AuthRedirectConfig.androidRedirectUrl] on mobile.
  ///
  /// Add the resolved URL to Supabase → Authentication → URL Configuration → Redirect URLs.
  final String authEmailRedirectUrl;

  /// Optional override from `--dart-define=SUPABASE_PASSWORD_RESET_REDIRECT_URL=...`.
  /// If empty, [resolvedPasswordResetRedirectUrl] uses web origin + [AuthRedirectConfig.webAuthPasswordResetPath]
  /// or [AuthRedirectConfig.androidPasswordResetRedirectUrl] on mobile.
  final String authPasswordResetRedirectUrl;

  const AppEnv({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.supabaseFunctionsBaseUrl = '',
    this.razorpayKeyId = '',
    this.authEmailRedirectUrl = '',
    this.authPasswordResetRedirectUrl = '',
  });

  /// Used for `signUp` (email confirmation / PKCE callback).
  String get resolvedAuthEmailRedirectUrl {
    final explicit = authEmailRedirectUrl.trim();
    if (explicit.isNotEmpty) return explicit;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty) {
        return '$origin${AuthRedirectConfig.webAuthCallbackPath}';
      }
    }
    return AuthRedirectConfig.androidRedirectUrl;
  }

  /// Used for `resetPasswordForEmail` only — must open the set-new-password screen, not the storefront.
  String get resolvedPasswordResetRedirectUrl {
    final explicit = authPasswordResetRedirectUrl.trim();
    if (explicit.isNotEmpty) return explicit;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty) {
        return '$origin${AuthRedirectConfig.webAuthPasswordResetPath}';
      }
    }
    return AuthRedirectConfig.androidPasswordResetRedirectUrl;
  }

  /// Trims whitespace and strips stray trailing `\` often introduced when a PowerShell
  /// `flutter run` line accidentally ends with `\)` next to `--dart-define=...=$env:...`.
  static String _cleanDefine(String value) {
    var v = value.trim();
    while (v.endsWith(r'\')) {
      v = v.substring(0, v.length - 1).trim();
    }
    return v;
  }

  /// Default `https://<ref>.supabase.co/functions/v1` when [explicitFromDefine] is empty.
  /// `--dart-define` does not read shell environment variables; Chrome runs often omit
  /// `SUPABASE_FUNCTIONS_BASE_URL` even when `SUPABASE_URL` is set.
  static String resolvedFunctionsBaseUrl({
    required String supabaseUrl,
    required String explicitFromDefine,
  }) {
    final explicit = _cleanDefine(explicitFromDefine);
    if (explicit.isNotEmpty) return explicit;
    final u = Uri.tryParse(_cleanDefine(supabaseUrl));
    if (u == null || !u.hasScheme || u.host.isEmpty) return '';
    final host = u.host.toLowerCase();
    if (!host.endsWith('.supabase.co')) return '';
    final ref = host.split('.').first;
    if (ref.isEmpty || ref == 'supabase') return '';
    return '${u.scheme}://$ref.supabase.co/functions/v1';
  }

  static AppEnv fromEnvironment() {
    const urlRaw = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const anonKeyRaw = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    const functionsBaseUrlRaw = String.fromEnvironment(
      'SUPABASE_FUNCTIONS_BASE_URL',
      defaultValue: '',
    );
    const razorpayPrimaryRaw = String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: '');
    const authRedirectRaw = String.fromEnvironment(
      'SUPABASE_AUTH_REDIRECT_URL',
      defaultValue: '',
    );
    const passwordResetRedirectRaw = String.fromEnvironment(
      'SUPABASE_PASSWORD_RESET_REDIRECT_URL',
      defaultValue: '',
    );
    final url = _cleanDefine(urlRaw);
    final anonKey = _cleanDefine(anonKeyRaw);
    final functionsBaseUrl = resolvedFunctionsBaseUrl(
      supabaseUrl: url,
      explicitFromDefine: functionsBaseUrlRaw,
    );
    final primary = _cleanDefine(razorpayPrimaryRaw);
    final razorpayKeyId = primary;
    final authEmailRedirectUrl = _cleanDefine(authRedirectRaw);
    final authPasswordResetRedirectUrl = _cleanDefine(passwordResetRedirectRaw);

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
      razorpayKeyId: razorpayKeyId,
      authEmailRedirectUrl: authEmailRedirectUrl,
      authPasswordResetRedirectUrl: authPasswordResetRedirectUrl,
    );
  }

  /// Same shape as [web/app-config.json.example] (Firebase Hosting root).
  factory AppEnv.fromHostedConfigJson(Map<String, dynamic> json) {
    final url = _cleanDefine(json['supabase_url']?.toString() ?? '');
    final anonKey = _cleanDefine(json['supabase_anon_key']?.toString() ?? '');
    final functionsBaseUrlRaw = json['supabase_functions_base_url']?.toString() ?? '';
    final razorpayPrimaryRaw = json['razorpay_key_id']?.toString() ?? '';
    final authRedirectRaw = json['supabase_auth_redirect_url']?.toString() ?? '';
    final passwordResetRedirectRaw = json['supabase_password_reset_redirect_url']?.toString() ?? '';

    final functionsBaseUrl = resolvedFunctionsBaseUrl(
      supabaseUrl: url,
      explicitFromDefine: functionsBaseUrlRaw,
    );
    final primary = _cleanDefine(razorpayPrimaryRaw);
    final razorpayKeyId = primary;
    final authEmailRedirectUrl = _cleanDefine(authRedirectRaw);
    final authPasswordResetRedirectUrl = _cleanDefine(passwordResetRedirectRaw);

    if (url.isEmpty || anonKey.isEmpty) {
      throw FlutterError(
        'app-config.json must include non-empty supabase_url and supabase_anon_key.',
      );
    }

    return AppEnv(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      supabaseFunctionsBaseUrl: functionsBaseUrl,
      razorpayKeyId: razorpayKeyId,
      authEmailRedirectUrl: authEmailRedirectUrl,
      authPasswordResetRedirectUrl: authPasswordResetRedirectUrl,
    );
  }

  /// Prefer [registerAppEnv]; otherwise compile-time defines ([fromEnvironment]).
  static AppEnv resolve() {
    final r = _registeredAppEnv;
    if (r != null) return r;
    return fromEnvironment();
  }
}
