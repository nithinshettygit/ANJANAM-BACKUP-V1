import 'dart:ui';

import 'universal_share.dart';

/// Stable, unique product URL (opens in app / web via [/product/:id] routing).
String storefrontProductShareUrl(String productId) {
  return universalShareUrl(ShareContentType.product, productId);
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
  final payload = UniversalSharePayload(
    contentType: ShareContentType.product,
    idOrSlug: productId,
    title: productTitle,
    description: priceFormatted,
    imageUrl: firstImageUrl,
  );
  await shareUniversalPayload(
    payload: payload,
    channel: ShareChannel.system,
    sharePositionOrigin: sharePositionOrigin,
  );
}
