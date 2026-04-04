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
  if (host == 'youtu.be') {
    for (final s in uri.pathSegments) {
      if (s.isNotEmpty && _looksLikeYoutubeVideoId(s)) return s;
    }
    return null;
  }

  if (!host.contains('youtube.com') && !host.contains('youtube-nocookie.com')) {
    return null;
  }

  final v = uri.queryParameters['v'];
  if (v != null && v.isNotEmpty && _looksLikeYoutubeVideoId(v)) {
    return v;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length >= 2) {
    final head = segments[0].toLowerCase();
    if (head == 'embed' || head == 'shorts' || head == 'live' || head == 'v') {
      final id = segments[1];
      if (_looksLikeYoutubeVideoId(id)) return id;
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
  if (id.length < 6 || id.length > 32) return false;
  return RegExp(r'^[0-9A-Za-z_-]+$').hasMatch(id);
}
