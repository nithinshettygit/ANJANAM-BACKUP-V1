import 'dart:html' as html;

const _defaultTitle = 'ANJANAM — Shop Online in India';
const _defaultDescription =
    'Shop products, digital articles, videos, books, and music on ANJANAM. Secure checkout with Razorpay.';
const _siteOrigin = 'https://anjanam.store';
const _defaultImage = '$_siteOrigin/icons/Icon-512.png';

String? _lastFingerprint;

void _setMeta(String name, String? content, {bool property = false}) {
  final value = content?.trim();
  if (value == null || value.isEmpty) return;
  final selector = property
      ? 'meta[property="$name"]'
      : 'meta[name="$name"]';
  final existing = html.document.querySelector(selector);
  final el = existing ?? html.MetaElement();
  if (existing == null) {
    if (property) {
      el.setAttribute('property', name);
    } else {
      el.setAttribute('name', name);
    }
    html.document.head!.append(el);
  }
  el.setAttribute('content', value);
}

void _setCanonical(String url) {
  final existing = html.document.querySelector('link[rel="canonical"]');
  final el = existing ?? html.LinkElement();
  if (existing == null) {
    el.setAttribute('rel', 'canonical');
    html.document.head!.append(el);
  }
  el.setAttribute('href', url);
}

String _truncate(String text, int max) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max - 1).trim()}…';
}

void updateSharePage({
  required String title,
  required String description,
  required String path,
  required String imageUrl,
  required String ogType,
}) {
  final canonical = path.startsWith('http')
      ? path
      : '$_siteOrigin${path.startsWith('/') ? path : '/$path'}';
  final safeTitle = _truncate(title, 70);
  final safeDescription = _truncate(description, 160);
  final image = imageUrl.trim().isNotEmpty ? imageUrl.trim() : _defaultImage;

  final fingerprint = '$safeTitle|$safeDescription|$canonical|$image';
  if (fingerprint == _lastFingerprint) return;
  _lastFingerprint = fingerprint;

  html.document.title = safeTitle;
  _setMeta('description', safeDescription);
  _setMeta('og:title', safeTitle, property: true);
  _setMeta('og:description', safeDescription, property: true);
  _setMeta('og:image', image, property: true);
  _setMeta('og:url', canonical, property: true);
  _setMeta('og:type', ogType, property: true);
  _setMeta('og:site_name', 'ANJANAM', property: true);
  _setMeta('twitter:card', 'summary_large_image');
  _setMeta('twitter:title', safeTitle);
  _setMeta('twitter:description', safeDescription);
  _setMeta('twitter:image', image);
  _setCanonical(canonical);
}

void resetToDefault() {
  _lastFingerprint = null;
  html.document.title = _defaultTitle;
  _setMeta('description', _defaultDescription);
  _setMeta('og:title', _defaultTitle, property: true);
  _setMeta('og:description', _defaultDescription, property: true);
  _setMeta('og:image', _defaultImage, property: true);
  _setMeta('og:url', _siteOrigin, property: true);
  _setMeta('og:type', 'website', property: true);
  _setCanonical(_siteOrigin);
}
