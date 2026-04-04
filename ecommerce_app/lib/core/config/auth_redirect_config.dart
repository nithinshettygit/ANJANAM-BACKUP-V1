/// Single place for values that must match **Supabase → Authentication → Redirect URLs**
/// and Android `AndroidManifest.xml` intent-filters.
///
/// **Supabase checklist**
/// - Site URL: e.g. `https://anjanam-app.web.app`
/// - Redirect URLs must include:
///   - `{your-web-origin}/auth-callback` (signup / email confirm)
///   - `{your-web-origin}/reset-password` (password reset from email)
///   - `com.anjanam.app://login-callback` and `.../` (email confirm on APK)
///   - `com.anjanam.app://reset-password` and `.../` (password reset on APK)
///
/// For CI/web builds where `Uri.base` is wrong, set `--dart-define=SUPABASE_AUTH_REDIRECT_URL=...` and
/// `--dart-define=SUPABASE_PASSWORD_RESET_REDIRECT_URL=...`.
abstract final class AuthRedirectConfig {
  /// Path for signup / email confirmation (PKCE callback).
  static const String webCallbackPath = '/auth-callback';

  /// Path for “forgot password” email link — app routes here to set a new password (not home).
  static const String webPasswordResetPath = '/reset-password';

  /// Custom URI scheme (matches typical reverse-DNS of `applicationId`).
  static const String androidScheme = 'com.anjanam.app';

  /// Host for email-confirm deep links.
  static const String androidHost = 'login-callback';

  /// Host for password-reset deep links.
  static const String androidPasswordResetHost = 'reset-password';

  static String get androidRedirectUrl => '$androidScheme://$androidHost/';

  static String get androidPasswordResetRedirectUrl =>
      '$androidScheme://$androidPasswordResetHost/';
}
