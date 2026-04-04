import 'dart:typed_data';

import 'package:image/image.dart' as img;

const int kProductImageMaxEdgePx = 1600;
const int kProductImageJpegQuality = 85;

/// Resizes large photos and encodes JPEG for smaller uploads (works on all platforms).
Uint8List? compressProductImageForUpload(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;

  img.Image work = decoded;
  final w = work.width;
  final h = work.height;
  if (w > kProductImageMaxEdgePx || h > kProductImageMaxEdgePx) {
    if (w >= h) {
      work = img.copyResize(work, width: kProductImageMaxEdgePx);
    } else {
      work = img.copyResize(work, height: kProductImageMaxEdgePx);
    }
  }

  return Uint8List.fromList(
    img.encodeJpg(work, quality: kProductImageJpegQuality),
  );
}
