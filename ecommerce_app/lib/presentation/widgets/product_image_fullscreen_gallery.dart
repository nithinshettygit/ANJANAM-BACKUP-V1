import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Fullscreen pinch-zoom gallery with swipe between images.
class ProductImageFullscreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ProductImageFullscreenGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ProductImageFullscreenGallery> createState() =>
      _ProductImageFullscreenGalleryState();
}

class _ProductImageFullscreenGalleryState extends State<ProductImageFullscreenGallery> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    final urls = _urls;
    _index = urls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, urls.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _urls =>
      widget.imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.image_not_supported_outlined,
                    color: Colors.white54, size: 64),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (context, i) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(urls[i]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.6,
                maxScale: PhotoViewComputedScale.covered * 4,
                filterQuality: FilterQuality.medium,
                errorBuilder: (ctx, err, st) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white38, size: 56),
                ),
              );
            },
            itemCount: urls.length,
            loadingBuilder: (context, event) => const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              ),
            ),
            pageController: _pageController,
            onPageChanged: (i) => setState(() => _index = i),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    '${_index + 1} / ${urls.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
