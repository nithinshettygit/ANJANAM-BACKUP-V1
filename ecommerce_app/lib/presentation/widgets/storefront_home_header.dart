import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/app_brand_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/cart/state/cart_controller.dart';
import '../../features/notifications/state/notifications_controller.dart';
import '../utils/main_shell_navigation.dart';

/// App bar toolbar height (below status bar). Two rows: brand + actions, then full-width search.
const double kStorefrontHomeToolbarHeight = 128;

/// Shared with [ProductSearchPage] hint / empty state copy.
const String kStorefrontSearchHint = 'Search products, categories, tags';

/// Capsule search field + dropdown share this max width so suggestions line up with the bar.
const double kStorefrontSearchBarMaxWidth = 520;

/// Shown as a square on the home header; title text sits to the right.
const double kStorefrontBrandLogoSize = 40;

/// Alternating Sanskrit / English brand with smooth fade + slide (continuous loop).
class StorefrontAnimatedBrandTitle extends StatefulWidget {
  const StorefrontAnimatedBrandTitle({super.key});

  @override
  State<StorefrontAnimatedBrandTitle> createState() =>
      _StorefrontAnimatedBrandTitleState();
}

class _StorefrontAnimatedBrandTitleState extends State<StorefrontAnimatedBrandTitle>
    with SingleTickerProviderStateMixin {
  static const _sanskrit = 'अंजनम्';
  static const _english = 'ANJANAM';
  static const _kannada = 'ಅಂಜನಂ';
  static const _titles = <String>[_sanskrit, _english, _kannada];

  static const _dwell = Duration(seconds: 6);
  static const _crossDuration = Duration(milliseconds: 640);

  /// Settled title index in [_titles].
  int _active = 0;

  Timer? _timer;
  late final AnimationController _cross;

  @override
  void initState() {
    super.initState();
    _cross = AnimationController(vsync: this, duration: _crossDuration);
    _cross.addStatusListener(_onCrossStatus);
    _timer = Timer.periodic(_dwell, (_) {
      if (!mounted || _cross.isAnimating) return;
      _cross.forward();
    });
  }

  void _onCrossStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _active = (_active + 1) % _titles.length;
      _cross.reset();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cross.removeStatusListener(_onCrossStatus);
    _cross.dispose();
    super.dispose();
  }

  TextStyle _titleStyle(ThemeData theme, {required String label}) {
    final isSanskrit = label == _sanskrit;
    final isEnglish = label == _english;
    return theme.textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: isSanskrit ? 25 : (isEnglish ? 22 : 24),
      letterSpacing: isEnglish ? 1.15 : 0.35,
      color: isSanskrit
          ? AppColors.brandSaffronDeep
          : (isEnglish ? const Color(0xFFFF6F00) : AppColors.brandGold),
      height: 1.05,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 5,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outgoing = _titles[_active];
    final incoming = _titles[(_active + 1) % _titles.length];

    final dpr = MediaQuery.of(context).devicePixelRatio;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: 'ANJANAM',
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                kAppBrandLogoAsset,
                width: kStorefrontBrandLogoSize,
                height: kStorefrontBrandLogoSize,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                cacheWidth: (kStorefrontBrandLogoSize * dpr).round(),
                cacheHeight: (kStorefrontBrandLogoSize * dpr).round(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 30,
                width: double.infinity,
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _cross,
                    builder: (context, child) {
                      final t = Curves.easeInOutCubic.transform(_cross.value);
                      const slidePx = 5.0;

                      Widget line(String label, double opacity, double dy) {
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, dy),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _titleStyle(theme, label: label),
                            ),
                          ),
                        );
                      }

                      return Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          line(
                            outgoing,
                            1.0 - t,
                            -slidePx * t,
                          ),
                          line(
                            incoming,
                            t,
                            slidePx * (1.0 - t),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const _BrandTitleAccentDots(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft triple-dot motif under the title (no heavy underline bar).
class _BrandTitleAccentDots extends StatelessWidget {
  const _BrandTitleAccentDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(AppColors.brandGold.withValues(alpha: 0.82)),
        const SizedBox(width: 6),
        _dot(const Color(0xFFFF6F00).withValues(alpha: 0.78)),
        const SizedBox(width: 6),
        _dot(AppColors.brandSaffronDeep.withValues(alpha: 0.9)),
      ],
    );
  }

  static Widget _dot(Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Full-width search pill with soft shadow (primary focal point under the title row).
class StorefrontHeaderSearchTrigger extends StatelessWidget {
  const StorefrontHeaderSearchTrigger({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Search. $kStorefrontSearchHint',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.searchFieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 24,
                    color: AppColors.brandSaffron,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      kStorefrontSearchHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Content for [AppBar.flexibleSpace]: Flipkart-style — row 1: brand (left) + notifications & cart (right);
/// row 2: full-width search below (not between brand and actions).
class StorefrontHomeHeaderBody extends ConsumerWidget {
  const StorefrontHomeHeaderBody({
    super.key,
    required this.onSearchTap,
  });

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartQty = ref.watch(cartTotalQuantityProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page - 4, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: StorefrontAnimatedBrandTitle(),
              ),
              IconButton(
                tooltip: 'Notifications',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.of(context).pushNamed('/notifications'),
                icon: ref.watch(unreadNotificationsCountProvider).when(
                  data: (count) {
                    final label = count > 99 ? '99+' : '$count';
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text(label, style: const TextStyle(fontSize: 10)),
                      child: const Icon(Icons.notifications_none_rounded, size: 24),
                    );
                  },
                  loading: () => const Icon(Icons.notifications_none_rounded, size: 24),
                  error: (_, __) => const Icon(Icons.notifications_none_rounded, size: 24),
                ),
              ),
              IconButton(
                tooltip: 'Cart',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => navigateToCartPage(ref, context),
                icon: cartQty > 0
                    ? Badge(
                        label: Text(
                          cartQty > 99 ? '99+' : '$cartQty',
                          style: const TextStyle(fontSize: 10),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined, size: 24),
                      )
                    : const Icon(Icons.shopping_cart_outlined, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StorefrontHeaderSearchTrigger(onTap: onSearchTap),
        ],
      ),
    );
  }
}
