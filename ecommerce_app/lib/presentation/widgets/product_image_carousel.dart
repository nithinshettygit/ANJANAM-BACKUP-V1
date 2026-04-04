import 'package:ecommerce_app/presentation/widgets/app_network_image.dart';
import 'package:ecommerce_app/presentation/widgets/product_image_fullscreen_gallery.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Storefront carousel: first image by default, dots, tap opens fullscreen zoom gallery.
class ProductImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final BorderRadius borderRadius;

  const ProductImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 260,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  late PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.imageUrls, widget.imageUrls)) {
      _page = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  List<String> get _urls =>
      widget.imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: AppNetworkImage(
          imageUrl: null,
          width: double.infinity,
          height: widget.height,
          fit: BoxFit.contain,
          borderRadius: BorderRadius.zero,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: widget.borderRadius,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => ProductImageFullscreenGallery(
                                imageUrls: urls,
                                initialIndex: i,
                              ),
                            ),
                          );
                        },
                        child: AppNetworkImage(
                          imageUrl: urls[i],
                          width: double.infinity,
                          height: widget.height,
                          fit: BoxFit.contain,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    );
                  },
                ),
                if (urls.length > 1)
                  Positioned(
                    bottom: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(urls.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: active
                                ? Colors.white
                                : Colors.white.withOpacity(0.45),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (urls.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Swipe for more photos · tap to zoom',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }
}
