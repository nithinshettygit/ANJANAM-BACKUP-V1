import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../utils/youtube_url_parser.dart';

/// Loads YouTube’s embed in a system WebView via a minimal HTML page.
///
/// YouTube **error 152-4** / **153** in WebViews is often tied to a bogus document context
/// (e.g. `Referer`/`origin` spoofed as `youtube.com`). We host the iframe on a real
/// storefront base URL ([youtubeEmbedContextBaseUri], aligned with `STOREFRONT_SHARE_BASE_URL`)
/// and set **referrer policy** on the iframe. Android also allows **third-party cookies** so
/// the player can initialize like in a normal browser tab.
class YoutubeEmbedWebView extends StatefulWidget {
  const YoutubeEmbedWebView({
    super.key,
    required this.videoId,
    this.userAgent,
    this.onEmbedReady,
    this.onMainFrameError,
  });

  final String videoId;
  final String? userAgent;
  final VoidCallback? onEmbedReady;
  final void Function(String description)? onMainFrameError;

  @override
  State<YoutubeEmbedWebView> createState() => _YoutubeEmbedWebViewState();
}

class _YoutubeEmbedWebViewState extends State<YoutubeEmbedWebView> {
  WebViewController? _controller;
  var _initializing = true;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(covariant YoutubeEmbedWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _createController();
    }
  }

  Future<void> _createController() async {
    setState(() {
      _initializing = true;
      _controller = null;
    });

    late final PlatformWebViewControllerCreationParams params;
    if (!kIsWeb && WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            widget.onEmbedReady?.call();
            if (mounted) setState(() => _initializing = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true) {
              widget.onMainFrameError?.call(error.description);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return _allowedNavigation(request.url)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );

    final ua = widget.userAgent;
    if (ua != null && ua.isNotEmpty) {
      await controller.setUserAgent(ua);
    }

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
      final cookiePlatform = WebViewCookieManager().platform;
      if (cookiePlatform is AndroidWebViewCookieManager) {
        await cookiePlatform.setAcceptThirdPartyCookies(platform, true);
      }
    }

    final baseUri = youtubeEmbedContextBaseUri();
    final html = _youtubeEmbedHtml(widget.videoId);
    await controller.loadHtmlString(html, baseUrl: baseUri.toString());

    if (!mounted) return;
    setState(() => _controller = controller);
  }

  static String _embedContextHost() => youtubeEmbedContextBaseUri().host.toLowerCase();

  /// Allow the local embed document, YouTube embed, streams, CDNs, and ad domains inside the player.
  static bool _allowedNavigation(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme == 'about') return true;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final h = uri.host.toLowerCase();
    if (h == _embedContextHost()) return true;
    return h.contains('youtube.com') ||
        h.contains('youtu.be') ||
        h.contains('googlevideo.com') ||
        h.contains('ytimg.com') ||
        h.contains('gstatic.com') ||
        h.contains('googleapis.com') ||
        h.contains('ggpht.com') ||
        h.contains('googleusercontent.com') ||
        h.contains('doubleclick.net') ||
        h.contains('googlesyndication.com') ||
        h.contains('googleadservices.com');
  }

  static String _youtubeEmbedHtml(String videoId) {
    final embedUri = youtubeEmbedUri(videoId);
    final src = const HtmlEscape(HtmlEscapeMode.attribute).convert(embedUri.toString());
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
html,body{margin:0;padding:0;height:100%;background:#000;}
iframe{border:0;width:100%;height:100%;position:absolute;left:0;top:0;}
</style>
</head>
<body>
<iframe src="$src" title="YouTube video"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
  allowfullscreen
  referrerpolicy="strict-origin-when-cross-origin"></iframe>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (c != null)
          WebViewWidget(controller: c)
        else
          const ColoredBox(color: Colors.black),
        if (_initializing || c == null)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
      ],
    );
  }
}
