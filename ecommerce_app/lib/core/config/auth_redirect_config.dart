/// Values that must match **Supabase → Authentication → URL Configuration → Redirect URLs**
/// and Android `AndroidManifest.xml` intent-filters.
///
/// ## Recommended production URLs (add every exact URL in Supabase)
///
/// **Email verification / PKCE callback**
/// - `https://anjanam.app/auth/callback`
/// - Optional staging: `https://anjanam.store/auth/callback`
///
/// **Forgot password (opens set-new-password screen)**
/// - `https://anjanam.app/auth/reset-password`
/// - Optional: `https://anjanam.store/auth/reset-password`
///
/// **Mobile-only `redirectTo` (when not using HTTPS App Links)**
/// - `com.anjanam.app://login-callback/` and `com.anjanam.app://reset-password/`
///
/// ## Android App Links
///
/// Host `anjanam.app` with path prefix `/auth` is declared in `AndroidManifest.xml`.
/// Serve `/.well-known/assetlinks.json` on that host (same signing cert as the APK).
/// If you already use `delegate_permission/common.handle_all_urls` for `anjanam.app`,
/// new `/auth/...` paths are covered without changing the JSON.
///
/// ## Web hosting (SPA)
///
/// Ensure `/auth/callback` and `/auth/reset-password` fall back to `index.html` so
/// Flutter web can read [Uri.base] and complete PKCE.
///
/// For CI/web builds where `Uri.base` is wrong, set:
/// `--dart-define=SUPABASE_AUTH_REDIRECT_URL=...` and
/// `--dart-define=SUPABASE_PASSWORD_RESET_REDIRECT_URL=...`.
abstract final class AuthRedirectConfig {
  /// Canonical path: email confirmation / PKCE (use in Supabase + Site URL flows).
  static const String webAuthCallbackPath = '/auth/callback';

  /// Legacy path — still routed so old Supabase redirect entries keep working.
  static const String webCallbackPathLegacy = '/auth-callback';

  /// Canonical path: password reset from email.
  static const String webAuthPasswordResetPath = '/auth/reset-password';

  /// Legacy path — still routed.
  static const String webPasswordResetPathLegacy = '/reset-password';

  /// Custom URI scheme (matches typical reverse-DNS of `applicationId`).
  static const String androidScheme = 'com.anjanam.app';

  /// Host for email-confirm deep links.
  static const String androidHost = 'login-callback';

  /// Host for password-reset deep links.
  static const String androidPasswordResetHost = 'reset-password';

  /// Host for product share deep links: `com.anjanam.app://product/<productId>`
  static const String androidProductHost = 'product';

  static String get androidRedirectUrl => '$androidScheme://$androidHost/';

  static String get androidPasswordResetRedirectUrl =>
      '$androidScheme://$androidPasswordResetHost/';
}
