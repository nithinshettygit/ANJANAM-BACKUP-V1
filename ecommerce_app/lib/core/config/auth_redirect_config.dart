/// Single place for values that must match **Supabase → Authentication → Redirect URLs**
/// and Android `AndroidManifest.xml` intent-filters.
///
/// **Supabase checklist**
/// - Site URL: e.g. `https://anjanam-app.web.app`
/// - Redirect URLs must include:
///   - `{your-web-origin}/auth-callback` (no literal `PORT`; use real ports for localhost)
///   - `com.anjanam.app://login-callback` and `com.anjanam.app://login-callback/`
///
/// For CI/web builds where `Uri.base` is wrong, set `--dart-define=SUPABASE_AUTH_REDIRECT_URL=https://.../auth-callback`.
abstract final class AuthRedirectConfig {
  /// Path segment after origin for Flutter web (PathUrlStrategy). Router must handle this path.
  static const String webCallbackPath = '/auth-callback';

  /// Custom URI scheme (matches typical reverse-DNS of `applicationId`).
  static const String androidScheme = 'com.anjanam.app';

  /// Authority/host for the auth deep link (`scheme://host/...`).
  static const String androidHost = 'login-callback';

  /// Default `emailRedirectTo` / `redirectTo` on Android when `SUPABASE_AUTH_REDIRECT_URL` is unset.
  static String get androidRedirectUrl => '$androidScheme://$androidHost/';
}
