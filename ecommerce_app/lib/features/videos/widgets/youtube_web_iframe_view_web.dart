// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../utils/youtube_url_parser.dart';

class YoutubeWebIFrameView extends StatefulWidget {
  const YoutubeWebIFrameView({
    super.key,
    required this.videoId,
    this.onReady,
    this.onError,
  });

  final String videoId;
  final VoidCallback? onReady;
  final VoidCallback? onError;

  @override
  State<YoutubeWebIFrameView> createState() => _YoutubeWebIFrameViewState();
}

class _YoutubeWebIFrameViewState extends State<YoutubeWebIFrameView> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerFactory();
  }

  @override
  void didUpdateWidget(covariant YoutubeWebIFrameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _registerFactory();
    }
  }

  void _registerFactory() {
    _viewType = 'yt-iframe-${widget.videoId}-${DateTime.now().microsecondsSinceEpoch}';
    final embedUri = youtubeEmbedUri(widget.videoId).replace(
      queryParameters: <String, String>{
        ...youtubeEmbedUri(widget.videoId).queryParameters,
        'autoplay': '0',
      },
    );
    final iframe = html.IFrameElement()
      ..src = embedUri.toString()
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..allowFullscreen = true
      ..allow =
          'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';

    iframe.onLoad.first.then((_) {
      if (mounted) widget.onReady?.call();
    });
    iframe.onError.first.then((_) {
      if (mounted) widget.onError?.call();
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => iframe);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
