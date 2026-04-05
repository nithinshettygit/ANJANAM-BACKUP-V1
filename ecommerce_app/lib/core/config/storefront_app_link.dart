import 'auth_redirect_config.dart';

/// Hosts for `https://…/product/<id>` links that should open the **native** app (Android App Links).
///
/// Must stay in sync with:
/// - `AndroidManifest.xml` intent-filter hosts (`pathPrefix` `/product`)
/// - `--dart-define=STOREFRONT_SHARE_BASE_URL=…` (host is merged in when set)
///
/// **Verified open-in-app** (tap link → app, no browser): host a valid
/// `/.well-known/assetlinks.json` on each HTTPS host (see AndroidManifest), with
/// `package_name` `com.anjanam.app` and your signing cert SHA-256. Use
/// `gradlew signingReport` (debug) or Play Console → App signing (release).
/// Check with: https://developers.google.com/digital-asset-links/tools/generator
///
/// Without that file, Android usually opens the **web** URL in Chrome. The optional
/// [productAppDeepLink] is for in-app / legacy handling, not for share text.
abstract final class StorefrontAppLink {
  static Set<String>? _hosts;

  static Set<String> _buildHosts() {
    const fromEnv = String.fromEnvironment(
      'STOREFRONT_SHARE_BASE_URL',
      defaultValue: 'https://anjanam-app.web.app',
    );
    final hosts = {
      'anjanam-app.web.app',
      'anjanam-app.firebaseapp.com',
      'anjanam.app',
    };
    final u = Uri.tryParse(fromEnv.trim());
    if (u != null && u.host.isNotEmpty) {
      hosts.add(u.host.toLowerCase());
    }
    return hosts;
  }

  static Set<String> get allowedHosts => _hosts ??= _buildHosts();

  /// `com.anjanam.app://product/<id>` — opens the installed app when tapped (no `assetlinks.json` needed).
  static Uri productAppDeepLink(String productId) {
    return Uri(
      scheme: AuthRedirectConfig.androidScheme,
      host: AuthRedirectConfig.androidProductHost,
      path: '/$productId',
    );
  }

  /// Non-null [productId] for HTTPS App Links or [productAppDeepLink] custom URIs.
  static String? productIdIfValid(Uri uri) {
    if (uri.scheme == AuthRedirectConfig.androidScheme &&
        uri.host.toLowerCase() == AuthRedirectConfig.androidProductHost.toLowerCase()) {
      if (uri.pathSegments.isEmpty) return null;
      final raw = uri.pathSegments.first;
      if (raw.isEmpty) return null;
      return Uri.decodeComponent(raw);
    }
    if (uri.scheme != 'https') return null;
    if (!allowedHosts.contains(uri.host.toLowerCase())) return null;
    final segs = uri.pathSegments;
    if (segs.length < 2) return null;
    if (segs[0] != 'product') return null;
    final raw = segs[1];
    if (raw.isEmpty) return null;
    return Uri.decodeComponent(raw);
  }
}
