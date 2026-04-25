import 'auth_redirect_config.dart';

/// Hosts for `https://…/product/<id>` links that should open the **native** app (Android App Links).
///
/// Must stay in sync with:
/// - `AndroidManifest.xml` intent-filter hosts (`pathPrefix` `/product`)
/// - `--dart-define=STOREFRONT_SHARE_BASE_URL=…` (host is merged in when set)
///
/// **Verified open-in-app** (tap HTTPS link → app): host valid
/// `/.well-known/assetlinks.json` on each share host (`anjanam.store`, etc.)
/// with `package_name` `com.anjanam.app` and **every** SHA-256 you ship with:
/// - **Debug** (`flutter run`): local debug keystore — run `gradlew signingReport` → Variant debug.
/// - **Release** (your upload keystore / local release APK).
/// - **Play Store**: Play App Signing certificate (Play Console → App integrity), if different from upload.
/// If the installed APK’s cert is not listed, Android opens the link in the browser.
/// Check with: https://developers.google.com/digital-asset-links/tools/generator
///
/// Without that file, Android usually opens the **web** URL in Chrome. The optional
/// [productAppDeepLink] is for in-app / legacy handling, not for share text.
abstract final class StorefrontAppLink {
  static String? _idFromCustomUri(Uri uri, String host) {
    if (uri.scheme != AuthRedirectConfig.androidScheme) return null;
    if (uri.host.toLowerCase() != host.toLowerCase()) return null;
    if (uri.pathSegments.isEmpty) return null;
    final raw = uri.pathSegments.first;
    if (raw.isEmpty) return null;
    return Uri.decodeComponent(raw);
  }

  static String? _idFromHttpsUri(Uri uri, String pathPrefix) {
    if (uri.scheme != 'https') return null;
    if (!allowedHosts.contains(uri.host.toLowerCase())) return null;
    final segs = uri.pathSegments;
    if (segs.length < 2) return null;
    if (segs[0] != pathPrefix) return null;
    final raw = segs[1];
    if (raw.isEmpty) return null;
    return Uri.decodeComponent(raw);
  }

  static Set<String>? _hosts;

  static Set<String> _buildHosts() {
    const fromEnv = String.fromEnvironment(
      'STOREFRONT_SHARE_BASE_URL',
      defaultValue: 'https://anjanam.store',
    );
    final hosts = {
      'anjanam.store',
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
    return _idFromCustomUri(uri, AuthRedirectConfig.androidProductHost) ?? _idFromHttpsUri(uri, 'product');
  }

  static Uri videoAppDeepLink(String videoId) {
    return Uri(
      scheme: AuthRedirectConfig.androidScheme,
      host: 'video',
      path: '/$videoId',
    );
  }

  static String? videoIdIfValid(Uri uri) {
    return _idFromCustomUri(uri, 'video') ?? _idFromHttpsUri(uri, 'video');
  }

  static Uri articleAppDeepLink(String articleId) {
    return Uri(
      scheme: AuthRedirectConfig.androidScheme,
      host: 'article',
      path: '/$articleId',
    );
  }

  static String? articleIdIfValid(Uri uri) {
    return _idFromCustomUri(uri, 'article') ?? _idFromHttpsUri(uri, 'article');
  }
}
