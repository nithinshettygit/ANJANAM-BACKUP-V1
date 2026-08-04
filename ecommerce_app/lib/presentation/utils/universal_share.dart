
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'storefront_share_mobile_io.dart' if (dart.library.html) 'storefront_share_mobile_stub.dart'
    as share_native;

enum ShareContentType { product, video, article }

enum ShareChannel { system, whatsapp, telegram, facebook, instagram }

class UniversalSharePayload {
  final ShareContentType contentType;
  final String idOrSlug;
  final String title;
  final String? description;
  final String? imageUrl;

  const UniversalSharePayload({
    required this.contentType,
    required this.idOrSlug,
    required this.title,
    this.description,
    this.imageUrl,
  });
}

String storefrontShareOrigin() {
  const fromEnv = String.fromEnvironment(
    'STOREFRONT_SHARE_BASE_URL',
    defaultValue: 'https://anjanam.store',
  );
  if (kIsWeb) {
    final o = Uri.base.origin;
    if (o.isNotEmpty) return o.replaceAll(RegExp(r'/+$'), '');
  }
  final trimmed = fromEnv.trim();
  return (trimmed.isEmpty ? 'https://anjanam.store' : trimmed).replaceAll(RegExp(r'/+$'), '');
}

String universalShareUrl(ShareContentType type, String idOrSlug) {
  final encoded = Uri.encodeComponent(idOrSlug);
  final origin = storefrontShareOrigin();
  switch (type) {
    case ShareContentType.product:
      return '$origin/product/$encoded';
    case ShareContentType.video:
      return '$origin/video/$encoded';
    case ShareContentType.article:
      return '$origin/article/$encoded';
  }
}

String buildUniversalShareMessage(UniversalSharePayload payload) {
  final link = universalShareUrl(payload.contentType, payload.idOrSlug);
  // Keep share text HTTPS-only so Android App Links can route reliably.
  switch (payload.contentType) {
    case ShareContentType.product:
      return '$link\n\n'
          '${payload.title}\n'
          'Check out this product on ANJANAM\n\n'
          '$link';
    case ShareContentType.video:
      return '$link\n\n'
          '${payload.title}\n'
          'Watch this video on ANJANAM\n\n'
          '$link';
    case ShareContentType.article:
      return '$link\n\n'
          '${payload.title}\n'
          'Read this article on ANJANAM\n\n'
          '$link';
  }
}

Future<void> copyUniversalShareLink(
  BuildContext context,
  UniversalSharePayload payload,
) async {
  final link = universalShareUrl(payload.contentType, payload.idOrSlug);
  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Link copied to clipboard.')),
  );
}

Future<void> shareUniversalPayload({
  required UniversalSharePayload payload,
  ShareChannel channel = ShareChannel.system,
  Rect? sharePositionOrigin,
}) async {
  final link = universalShareUrl(payload.contentType, payload.idOrSlug);
  final message = buildUniversalShareMessage(payload);
  final subject = payload.title;

  if (channel == ShareChannel.telegram) {
    final uri = Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(payload.title)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  } else if (channel == ShareChannel.facebook) {
    final uri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(link)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }

  // WhatsApp + Instagram should receive image + caption text together.
  // We intentionally use native share payload instead of wa.me text-only URLs.
  final canAttachImage = !kIsWeb && payload.imageUrl != null && payload.imageUrl!.trim().isNotEmpty;
  if (canAttachImage) {
    final ok = await share_native.tryShareWithImage(
      text: message,
      subject: subject,
      imageUrl: payload.imageUrl!.trim(),
      sharePositionOrigin: sharePositionOrigin,
    );
    if (ok) return;
  }
  await SharePlus.instance.share(
    ShareParams(
      text: message,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

Future<void> showUniversalShareSheet(
  BuildContext context, {
  required UniversalSharePayload payload,
  Rect? sharePositionOrigin,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final imageUrl = payload.imageUrl?.trim();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 10),
              Text(payload.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ShareChip(label: 'System Share', icon: Icons.share, onTap: () async => shareUniversalPayload(payload: payload, channel: ShareChannel.system, sharePositionOrigin: sharePositionOrigin)),
                  _ShareChip(label: 'WhatsApp', icon: Icons.chat_bubble_outline, onTap: () async => shareUniversalPayload(payload: payload, channel: ShareChannel.whatsapp, sharePositionOrigin: sharePositionOrigin)),
                  _ShareChip(label: 'Instagram', icon: Icons.camera_alt_outlined, onTap: () async => shareUniversalPayload(payload: payload, channel: ShareChannel.instagram, sharePositionOrigin: sharePositionOrigin)),
                  _ShareChip(label: 'Telegram', icon: Icons.send_outlined, onTap: () async => shareUniversalPayload(payload: payload, channel: ShareChannel.telegram, sharePositionOrigin: sharePositionOrigin)),
                  _ShareChip(label: 'Facebook', icon: Icons.public, onTap: () async => shareUniversalPayload(payload: payload, channel: ShareChannel.facebook, sharePositionOrigin: sharePositionOrigin)),
                  _ShareChip(label: 'Copy Link', icon: Icons.link, onTap: () async => copyUniversalShareLink(context, payload)),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ShareChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  const _ShareChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () async {
        Navigator.of(context).pop();
        await onTap();
      },
    );
  }
}
