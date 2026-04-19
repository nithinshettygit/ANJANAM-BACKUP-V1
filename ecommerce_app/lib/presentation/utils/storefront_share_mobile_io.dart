import 'dart:io';
import 'dart:ui';

import 'package:ecommerce_app/core/network/http_resilience.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> tryShareWithImage({
  required String text,
  required String subject,
  required String imageUrl,
  Rect? sharePositionOrigin,
}) async {
  try {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !uri.hasScheme) return false;
    final response = await HttpResilience.get(uri, timeout: const Duration(seconds: 10));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return false;

    final header = response.headers['content-type'] ?? '';
    final ext = header.contains('png') ? 'png' : 'jpg';
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}anjanam_share_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final file = File(path);
    await file.writeAsBytes(response.bodyBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mime)],
        text: text,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
