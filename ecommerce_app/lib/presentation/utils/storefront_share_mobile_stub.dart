import 'dart:ui';

/// Web build; image+file share uses IO-only APIs in [storefront_share_mobile_io.dart].
Future<bool> tryShareProductWithImage({
  required String text,
  required String subject,
  required String imageUrl,
  Rect? sharePositionOrigin,
}) async =>
    false;
