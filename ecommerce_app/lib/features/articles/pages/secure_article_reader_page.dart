import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ecommerce_app/core/network/http_resilience.dart';
import 'package:printing/printing.dart';

class SecureArticleReaderPage extends StatefulWidget {
  const SecureArticleReaderPage({
    super.key,
    required this.title,
    required this.signedPdfUrl,
  });

  final String title;
  final String signedPdfUrl;

  @override
  State<SecureArticleReaderPage> createState() => _SecureArticleReaderPageState();
}

class _SecureArticleReaderPageState extends State<SecureArticleReaderPage> {
  static const MethodChannel _secureChannel =
      MethodChannel('com.anjanam.app/window_secure');
  late final Future<Uint8List> _pdfBytesFuture;

  @override
  void initState() {
    super.initState();
    _lockScreenCapture();
    _pdfBytesFuture = _downloadPdfBytes();
  }

  Future<void> _lockScreenCapture() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _secureChannel.invokeMethod<void>('enable');
    }
  }

  Future<void> _unlockScreenCapture() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _secureChannel.invokeMethod<void>('disable');
    }
  }

  Future<Uint8List> _downloadPdfBytes() async {
    final uri = Uri.parse(widget.signedPdfUrl);
    final res = await HttpResilience.get(uri, timeout: const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Could not load article PDF (HTTP ${res.statusCode}).');
    }
    final bytes = res.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception('Article PDF is empty.');
    }
    return bytes;
  }

  @override
  void dispose() {
    _unlockScreenCapture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: kIsWeb
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Secure article reader is available on mobile app .',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FutureBuilder<Uint8List>(
              future: _pdfBytesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Could not open this article right now. Please try again.\n${snapshot.error ?? ''}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final bytes = snapshot.data!;
                return Stack(
                  children: [
                    PdfPreview(
                      build: (_) async => bytes,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      allowPrinting: false,
                      allowSharing: false,
                      canDebug: false,
                      useActions: false,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.black.withValues(alpha: 0.06),
                          child: const Text(
                            'Protected content - downloads, sharing, and copy are disabled.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
