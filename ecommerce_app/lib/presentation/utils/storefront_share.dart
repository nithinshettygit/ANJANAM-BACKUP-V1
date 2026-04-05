import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'storefront_share_mobile_io.dart' if (dart.library.html) 'storefront_share_mobile_stub.dart'
    as share_native;

/// Public storefront origin for shared links.
///
/// On web, uses the current page origin so dev/staging shares match the open site.
///
/// On mobile, the default matches Firebase Hosting for project `anjanam-app` (see
/// `.firebaserc`): `https://anjanam-app.web.app`. Custom domains (e.g. anjanam.app)
/// only work after DNS + Hosting are configured; until then, shares would show
/// "site can't be reached" if the default pointed at an unused domain.
///
/// Override at build time: `--dart-define=STOREFRONT_SHARE_BASE_URL=https://anjanam.app`
String storefrontShareOrigin() {
  const fromEnv = String.fromEnvironment(
    'STOREFRONT_SHARE_BASE_URL',
    defaultValue: 'https://anjanam-app.web.app',
  );
  if (kIsWeb) {
    final o = Uri.base.origin;
    if (o.isNotEmpty) {
      var s = o;
      while (s.endsWith('/')) {
        s = s.substring(0, s.length - 1);
      }
      return s;
    }
  }
  var base = fromEnv.trim();
  if (base.isEmpty) base = 'https://anjanam-app.web.app';
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return base;
}

/// Stable, unique product URL (opens in app / web via [/product/:id] routing).
String storefrontProductShareUrl(String productId) {
  final origin = storefrontShareOrigin();
  return '$origin/product/${Uri.encodeComponent(productId)}';
}

String _shareMessage({
  required String productTitle,
  required String priceFormatted,
  required String productUrl,
}) {
  // Single HTTPS URL: opens in browser; Android App Links open the app when verified.
  return 'Check out this product on ANJANAM:\n'
      'Product: $productTitle\n'
      'Price: $priceFormatted\n'
      '\n'
      '$productUrl';
}

/// Opens the native share sheet with product text and link; on mobile, attaches the
/// first product image when download succeeds.
Future<void> shareStorefrontProduct({
  required String productTitle,
  required String priceFormatted,
  required String productId,
  String? firstImageUrl,
  Rect? sharePositionOrigin,
}) async {
  final url = storefrontProductShareUrl(productId);
  final text = _shareMessage(
    productTitle: productTitle,
    priceFormatted: priceFormatted,
    productUrl: url,
  );

  if (!kIsWeb &&
      firstImageUrl != null &&
      firstImageUrl.trim().isNotEmpty) {
    final ok = await share_native.tryShareProductWithImage(
      text: text,
      subject: productTitle,
      imageUrl: firstImageUrl.trim(),
      sharePositionOrigin: sharePositionOrigin,
    );
    if (ok) return;
  }

  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: productTitle,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}
