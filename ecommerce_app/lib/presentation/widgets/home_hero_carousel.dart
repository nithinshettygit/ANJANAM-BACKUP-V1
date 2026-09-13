import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/home_content/domain/home_hero_banner.dart';
import '../utils/home_banner_navigation.dart';
import 'app_network_image.dart';

/// Auto-advancing hero banner strip for the storefront home screen.
class HomeHeroCarousel extends ConsumerStatefulWidget {
  const HomeHeroCarousel({
    super.key,
    required this.banners,
    this.height = 168,
    this.autoAdvance = const Duration(seconds: 4),
  });

  final List<HomeHeroBanner> banners;
  final double height;
  final Duration autoAdvance;

  @override
  ConsumerState<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends ConsumerState<HomeHeroCarousel>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late final AnimationController _progressController;
  double? _pageViewportFraction;
  bool _isWideLayout = false;
  int _index = 0;
  bool _isPointerDown = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.autoAdvance,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goToNextBanner();
        }
      });
    _restartProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    final viewportFraction = width >= 600 ? 0.48 : 0.88;
    _isWideLayout = width >= 600;
    if (_pageViewportFraction == viewportFraction) return;

    final previousController =
        _pageViewportFraction == null ? null : _pageController;
    _pageViewportFraction = viewportFraction;
    _pageController = PageController(
      initialPage: _index,
      viewportFraction: viewportFraction,
    );
    previousController?.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoAdvance != widget.autoAdvance) {
      _progressController.duration = widget.autoAdvance;
      _restartProgress();
    }
    if (oldWidget.banners.length != widget.banners.length) {
      _index = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _restartProgress();
    }
  }

  Future<void> _goToNextBanner() async {
    if (!mounted || !_pageController.hasClients || widget.banners.length <= 1) {
      return;
    }
    final next = (_index + 1) % widget.banners.length;
    await _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _restartProgress() {
    _progressController.stop();
    _progressController.value = 0;
    if (!mounted || widget.banners.length <= 1 || _isPointerDown) return;
    _progressController.forward(from: 0);
  }

  void _pauseProgress() {
    _isPointerDown = true;
    _progressController.stop();
  }

  void _resumeProgress() {
    _isPointerDown = false;
    if (widget.banners.length <= 1) return;
    _progressController.forward(from: _progressController.value);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: (_) => _pauseProgress(),
          onPointerUp: (_) => _resumeProgress(),
          onPointerCancel: (_) => _resumeProgress(),
          child: SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _pageController,
              padEnds: !_isWideLayout,
              itemCount: banners.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _restartProgress();
              },
              itemBuilder: (context, i) {
                final b = banners[i];
                return Padding(
                  padding: _isWideLayout
                      ? EdgeInsets.only(
                          left: i == 0 ? 0 : 10,
                          right: 10,
                        )
                      : const EdgeInsets.symmetric(horizontal: 6),
                  child: Material(
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    elevation: 5,
                    shadowColor: AppColors.brandSaffron.withValues(alpha: 0.12),
                    child: InkWell(
                      onTap: () => openHomeBannerTarget(context, ref, b),
                      child: AppNetworkImage(
                        imageUrl: b.imageUrl,
                        width: double.infinity,
                        height: widget.height,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.5,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.45),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      final fillWidth =
                          constraints.maxWidth * _progressController.value;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: fillWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6F00),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
