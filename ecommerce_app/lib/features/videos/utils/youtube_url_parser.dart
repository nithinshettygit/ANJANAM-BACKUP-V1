/// Base URL of the storefront site used as the **document URL** for in-app YouTube embeds.
///
/// YouTube increasingly rejects WebViews that fake `Referer`/`origin` as `youtube.com` (error **152-4**).
/// The embed must declare a real HTTPS origin aligned with your app (same default as
/// [StorefrontAppLink] / `STOREFRONT_SHARE_BASE_URL`).
Uri youtubeEmbedContextBaseUri() {
  const raw = String.fromEnvironment(
    'STOREFRONT_SHARE_BASE_URL',
    defaultValue: 'https://anjanam-app.web.app',
  );
  final u = Uri.tryParse(raw.trim());
  if (u == null || u.host.isEmpty) {
    return Uri.parse('https://anjanam-app.web.app/');
  }
  return Uri(
    scheme: u.scheme.isEmpty ? 'https' : u.scheme,
    host: u.host,
    port: u.hasPort ? u.port : null,
    path: '/',
  );
}

/// `scheme://host[:port]` for IFrame `origin=` (no path).
String youtubeEmbedContextOrigin() => youtubeEmbedContextBaseUri().origin;

/// Opens the standard watch page (works even when in-app embed is blocked).
Uri youtubeWatchPageUri(String videoId) =>
    Uri.https('www.youtube.com', '/watch', <String, String>{'v': videoId});

/// Opens the Shorts URL (better deep-link into the YouTube app for vertical Shorts).
Uri youtubeShortsPageUri(String videoId) =>
    Uri.https('www.youtube.com', '/shorts/$videoId');

/// Official embed URL (same document YouTube serves in a browser iframe). Prefer this over
/// custom HTML + IFrame API in WebView for reliable playback when embedding is allowed.
Uri youtubeEmbedUri(String videoId) => Uri.https(
      'www.youtube.com',
      '/embed/$videoId',
      <String, String>{
        'playsinline': '1',
        'rel': '0',
        'modestbranding': '1',
        'iv_load_policy': '3',
        'origin': youtubeEmbedContextOrigin(),
        'enablejsapi': '1',
      },
    );

/// True when the saved link is a `/shorts/…` URL (not a generic short *length* video).
bool isYoutubeShortsUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return false;

  var uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    uri = Uri.tryParse('https://$trimmed');
  }
  if (uri == null || uri.host.isEmpty) return false;

  final host = uri.host.toLowerCase();
  if (!host.contains('youtube.com') && !host.contains('youtube-nocookie.com')) {
    return false;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  return segments.isNotEmpty && segments.first.toLowerCase() == 'shorts';
}

/// Parses YouTube watch / share URLs and returns the video id when valid.
String? extractYoutubeVideoId(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  var uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    uri = Uri.tryParse('https://$trimmed');
  }
  if (uri == null || uri.host.isEmpty) return null;

  final host = uri.host.toLowerCase();
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    for (final s in uri.pathSegments) {
      final id = _stripYoutubeIdNoise(s);
      if (id != null) return id;
    }
    return null;
  }

  if (!host.contains('youtube.com') && !host.contains('youtube-nocookie.com')) {
    return null;
  }

  final v = uri.queryParameters['v'];
  if (v != null && v.isNotEmpty) {
    final id = _stripYoutubeIdNoise(v);
    if (id != null) return id;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length >= 2) {
    final head = segments[0].toLowerCase();
    if (head == 'embed' || head == 'shorts' || head == 'live' || head == 'v') {
      final id = _stripYoutubeIdNoise(segments[1]);
      if (id != null) return id;
    }
  }

  return null;
}

/// Returns true when [rawUrl] parses to a non-null YouTube video id.
bool isValidYoutubeUrl(String rawUrl) => extractYoutubeVideoId(rawUrl) != null;

/// Default high-quality still from YouTube (no API key).
String youtubeDefaultThumbnailUrl(String videoId) =>
    'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

bool _looksLikeYoutubeVideoId(String id) {
  // Typical ids are 11 chars; allow a slightly wider range for future formats.
  if (id.length < 6 || id.length > 32) return false;
  return RegExp(r'^[0-9A-Za-z_-]+$').hasMatch(id);
}

/// Strips tracking noise (e.g. `id&si=...` pasted into admin) from a candidate id.
String? _stripYoutubeIdNoise(String raw) {
  final amp = raw.indexOf('&');
  final cut = amp >= 0 ? raw.substring(0, amp) : raw;
  final trimmed = cut.trim();
  if (!_looksLikeYoutubeVideoId(trimmed)) return null;
  return trimmed;
}
