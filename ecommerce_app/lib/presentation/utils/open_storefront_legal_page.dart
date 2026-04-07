import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/storefront_legal_urls.dart';

Future<void> openStorefrontLegalPage(
  BuildContext context,
  StorefrontLegalPage page,
) async {
  final uri = Uri.parse(storefrontLegalPageUrl(page));
  final ok = await canLaunchUrl(uri);
  if (!ok) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.toString()}')),
      );
    }
    return;
  }
  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: kIsWeb ? '_blank' : null,
  );
}
