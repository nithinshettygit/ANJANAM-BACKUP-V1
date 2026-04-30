import 'package:ecommerce_app/core/config/auth_redirect_config.dart';

/// High-level kind of link sent by Supabase (email confirm vs password recovery).
enum AuthEmailLinkKind {
  /// PKCE `code` exchange (signup / email verification, magic link).
  pkceCallback,

  /// Recovery session — user sets a new password.
  passwordRecovery,
}

bool _isAuthEmailLinkHost(String host) {
  final h = host.toLowerCase();
  return h == 'anjanam.app' ||
      h == 'www.anjanam.app' ||
      h == 'anjanam.store' ||
      h == 'anjanam-app.web.app' ||
      h == 'anjanam-app.firebaseapp.com';
}

String _normalizePath(String path) {
  var p = path.trim();
  if (p.isEmpty) return '/';
  if (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

/// Classifies URIs that should open the in-app auth callback or reset-password flow.
///
/// Covers:
/// - `https://anjanam.app/auth/callback` (and legacy `/auth-callback` on supported hosts)
/// - `https://anjanam.app/auth/reset-password` (and legacy `/reset-password`)
/// - `com.anjanam.app://login-callback` / `com.anjanam.app://reset-password` (mobile `redirectTo`)
AuthEmailLinkKind? classifyAuthEmailLink(Uri uri) {
  if (uri.scheme == AuthRedirectConfig.androidScheme) {
    if (uri.host == AuthRedirectConfig.androidHost) {
      return AuthEmailLinkKind.pkceCallback;
    }
    if (uri.host == AuthRedirectConfig.androidPasswordResetHost) {
      return AuthEmailLinkKind.passwordRecovery;
    }
    return null;
  }
  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (!_isAuthEmailLinkHost(uri.host)) return null;
    final path = _normalizePath(uri.path);
    if (path == AuthRedirectConfig.webAuthCallbackPath ||
        path == AuthRedirectConfig.webCallbackPathLegacy) {
      return AuthEmailLinkKind.pkceCallback;
    }
    if (path == AuthRedirectConfig.webAuthPasswordResetPath ||
        path == AuthRedirectConfig.webPasswordResetPathLegacy) {
      return AuthEmailLinkKind.passwordRecovery;
    }
  }
  return null;
}

/// Route name registered in [AppRouter] for each [AuthEmailLinkKind].
String materialRouteForAuthEmailLink(AuthEmailLinkKind kind) {
  switch (kind) {
    case AuthEmailLinkKind.pkceCallback:
      return AuthRedirectConfig.webAuthCallbackPath;
    case AuthEmailLinkKind.passwordRecovery:
      return AuthRedirectConfig.webAuthPasswordResetPath;
  }
}

/// OAuth-style errors sometimes appear in query or URL fragment.
String? parseAuthCallbackErrorFromUri(Uri uri) {
  final q = uri.queryParameters;
  final err = q['error']?.trim();
  if (err != null && err.isNotEmpty) {
    final desc = q['error_description']?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return err;
  }
  final frag = uri.fragment.trim();
  if (frag.isEmpty) return null;
  final parsed = Uri.splitQueryString(frag);
  final fe = parsed['error']?.trim();
  if (fe != null && fe.isNotEmpty) {
    final desc = parsed['error_description']?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return fe;
  }
  return null;
}
