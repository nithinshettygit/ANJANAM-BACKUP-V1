/// Values that must match **Supabase → Authentication → URL Configuration → Redirect URLs**
/// and Android `AndroidManifest.xml` intent-filters.
///
/// ## Recommended production URLs (add every exact URL in Supabase)
///
/// **Email verification / PKCE callback**
/// - `https://anjanam.store/auth/callback`
/// - `https://anjanam.app/auth/callback`
/// - Optional: `https://anjanam-app.web.app/auth/callback`
///
/// **Forgot password (opens set-new-password screen)**
/// - `https://anjanam.store/auth/reset-password`
/// - `https://anjanam.app/auth/reset-password`
/// - Optional: `https://anjanam-app.web.app/auth/reset-password`
///
/// **Mobile-only custom scheme (fallback)**
/// - `com.anjanam.app://login-callback/` and `com.anjanam.app://reset-password/`
///
/// Prefer **HTTPS store/app links** for password-reset emails so Gmail/browser
/// clients open the Flutter web set-password page (or the APK via App Links).
/// Custom-scheme-only `redirectTo` often fails and Supabase falls back to Site URL
/// (`https://anjanam.store/`) — which loads the storefront without the reset form.
///
/// ## Android App Links
///
/// Host `anjanam.store` / `anjanam.app` with path prefix `/auth` is declared in
/// `AndroidManifest.xml`. Serve `/.well-known/assetlinks.json` on those hosts.
///
/// ## Web hosting (SPA)
///
/// Ensure `/auth/callback` and `/auth/reset-password` fall back to `index.html` so
/// Flutter web can read [Uri.base] and complete PKCE / recovery.
///
/// For CI/web builds set:
/// `--dart-define=SUPABASE_AUTH_REDIRECT_URL=...` and
/// `--dart-define=SUPABASE_PASSWORD_RESET_REDIRECT_URL=...`.
abstract final class AuthRedirectConfig {
  /// Primary public storefront host (password/confirm emails when not overridden).
  static const String productionWebOrigin = 'https://anjanam.store';

  /// Canonical path: email confirmation / PKCE (use in Supabase + Site URL flows).
  static const String webAuthCallbackPath = '/auth/callback';

  /// Legacy path — still routed so old Supabase redirect entries keep working.
  static const String webCallbackPathLegacy = '/auth-callback';

  /// Canonical path: password reset from email.
  static const String webAuthPasswordResetPath = '/auth/reset-password';

  /// Legacy path — still routed.
  static const String webPasswordResetPathLegacy = '/reset-password';

  /// Production HTTPS targets for auth emails (must be allow-listed in Supabase).
  static String get productionWebAuthCallbackUrl =>
      '$productionWebOrigin$webAuthCallbackPath';

  static String get productionWebPasswordResetUrl =>
      '$productionWebOrigin$webAuthPasswordResetPath';

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

