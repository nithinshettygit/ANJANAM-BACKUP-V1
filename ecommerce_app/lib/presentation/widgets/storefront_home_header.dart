import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
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

/// Web: single row (brand | search | actions); compact bar → more vertical room for content below.
const double kStorefrontHomeWebToolbarHeight = 60;

/// Web viewports narrower than this use the two-row header (same as Android) to avoid overflow.
const double kStorefrontHomeWebInlineSearchMinWidth = 640;

/// Shared with [ProductSearchPage] hint / empty state copy.
const String kStorefrontSearchHint = 'Search products, categories, tags';

/// Capsule search field + dropdown share this max width so suggestions line up with the bar.
const double kStorefrontSearchBarMaxWidth = 520;

/// Shown as a square on the home header; title text sits to the right.
const double kStorefrontBrandLogoSize = 40;

/// Alternating Sanskrit / English brand with smooth fade + slide (continuous loop).
class StorefrontAnimatedBrandTitle extends StatefulWidget {
  const StorefrontAnimatedBrandTitle({
    super.key,
    /// Web desktop one-row header: shorter logo, single title line, no accent dots.
    this.compact = false,
  });

  final bool compact;

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
    final compact = widget.compact;
    return theme.textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: compact
          ? (isSanskrit ? 18.5 : (isEnglish ? 16.5 : 17.5))
          : (isSanskrit ? 25 : (isEnglish ? 22 : 24)),
      letterSpacing: isEnglish ? (compact ? 0.85 : 1.15) : 0.35,
      color: isSanskrit
          ? AppColors.brandSaffronDeep
          : (isEnglish ? const Color(0xFFFF6F00) : AppColors.brandGold),
      height: compact ? 1.0 : 1.05,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: compact ? 3 : 5,
          offset: Offset(0, compact ? 0.5 : 1),
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
    final compact = widget.compact;
    final logoSize = compact ? 32.0 : kStorefrontBrandLogoSize;
    final logoRadius = compact ? 8.0 : 10.0;
    final titleLineH = compact ? 22.0 : 30.0;
    final logoGap = compact ? 10.0 : 12.0;
    final slidePx = compact ? 3.0 : 5.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: 'ANJANAM',
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(logoRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: compact ? 6 : 10,
                  offset: Offset(0, compact ? 2 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(logoRadius),
              child: Image.asset(
                kAppBrandLogoAsset,
                width: logoSize,
                height: logoSize,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                cacheWidth: (logoSize * dpr).round(),
                cacheHeight: (logoSize * dpr).round(),
              ),
            ),
          ),
        ),
        SizedBox(width: logoGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: titleLineH,
                width: double.infinity,
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _cross,
                    builder: (context, child) {
                      final t = Curves.easeInOutCubic.transform(_cross.value);

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
              if (!compact) ...[
                const SizedBox(height: 6),
                const _BrandTitleAccentDots(),
              ],
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
    /// Tighter padding / icon for inline web toolbar (between brand and actions).
    this.dense = false,
    /// Web desktop one-row header: fixed ~38px height, smaller radius and hint text.
    this.webInlineCompact = false,
  });

  final VoidCallback onTap;
  final bool dense;
  final bool webInlineCompact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hPad = webInlineCompact
        ? 10.0
        : (dense ? 12.0 : 14.0);
    final vPad = webInlineCompact ? 0.0 : (dense ? 8.0 : 12.0);
    final iconSize = webInlineCompact ? 20.0 : (dense ? 22.0 : 24.0);
    final gap = webInlineCompact ? 8.0 : (dense ? 10.0 : 12.0);
    final radius = webInlineCompact ? 10.0 : 14.0;
    final fixedH = webInlineCompact ? 38.0 : null;

    final hintStyle = webInlineCompact
        ? textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          )
        : textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          );

    final row = Row(
      children: [
        Icon(
          Icons.search_rounded,
          size: iconSize,
          color: AppColors.brandSaffron,
        ),
        SizedBox(width: gap),
        Expanded(
          child: Text(
            kStorefrontSearchHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hintStyle,
          ),
        ),
      ],
    );

    Widget inner = Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: webInlineCompact
          ? Align(alignment: Alignment.centerLeft, child: row)
          : row,
    );
    if (fixedH != null) {
      inner = SizedBox(height: fixedH, child: inner);
    }

    return Semantics(
      button: true,
      label: 'Search. $kStorefrontSearchHint',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.searchFieldFill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: webInlineCompact ? 6 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: inner,
          ),
        ),
      ),
    );
  }
}

/// Native home: brand + notification/cart collapse with scroll; search stays visible.
class _MobileCollapsingHomeHeaderContent extends ConsumerWidget {
  const _MobileCollapsingHomeHeaderContent({
    required this.collapseT,
    required this.onSearchTap,
  });

  /// 0 = full header, 1 = only search row visible.
  final double collapseT;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = collapseT.clamp(0.0, 1.0);
    final cartQty = ref.watch(cartTotalQuantityProvider);
    final heightFactor = (1.0 - t).clamp(0.0, 1.0);
    final opacity = (1.0 - t).clamp(0.0, 1.0);

    final brandRow = Row(
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
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        lerpDouble(4, 6, t)!,
        AppSpacing.page - 4,
        lerpDouble(10, 6, t)!,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: heightFactor,
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, -14 * t),
                  child: brandRow,
                ),
              ),
            ),
          ),
          SizedBox(height: 8 * (1.0 - t)),
          StorefrontHeaderSearchTrigger(
            onTap: onSearchTap,
            dense: t > 0.28,
          ),
        ],
      ),
    );
  }
}

/// Content for [AppBar.flexibleSpace].
///
/// **Mobile:** brand + actions on row 1; full-width search on row 2.
///
/// **Web:** brand (left) | search (expanded) | notifications & cart (right) — one row, shorter bar.
class StorefrontHomeHeaderBody extends ConsumerWidget {
  const StorefrontHomeHeaderBody({
    super.key,
    required this.onSearchTap,
    /// Native app only: 0–1 scroll-driven collapse (search stays). Ignored on web.
    this.mobileScrollCollapseT,
  });

  final VoidCallback onSearchTap;
  final double? mobileScrollCollapseT;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget headerTwoRow({
      required EdgeInsetsGeometry padding,
      bool denseSearch = false,
    }) {
      final cartQty = ref.watch(cartTotalQuantityProvider);
      return Padding(
        padding: padding,
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
            StorefrontHeaderSearchTrigger(
              onTap: onSearchTap,
              dense: denseSearch,
            ),
          ],
        ),
      );
    }

    if (!kIsWeb) {
      final collapse = mobileScrollCollapseT;
      if (collapse != null) {
        return _MobileCollapsingHomeHeaderContent(
          collapseT: collapse,
          onSearchTap: onSearchTap,
        );
      }
      return headerTwoRow(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page - 4, 10),
      );
    }

    /// Narrow web windows: same two-row stack as mobile (avoids horizontal overflow).
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < kStorefrontHomeWebInlineSearchMinWidth) {
          return headerTwoRow(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            denseSearch: true,
          );
        }
        final cartQty = ref.watch(cartTotalQuantityProvider);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 2,
                fit: FlexFit.loose,
                child: StorefrontAnimatedBrandTitle(compact: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: StorefrontHeaderSearchTrigger(
                  onTap: onSearchTap,
                  dense: true,
                  webInlineCompact: true,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Notifications',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.of(context).pushNamed('/notifications'),
                icon: ref.watch(unreadNotificationsCountProvider).when(
                  data: (count) {
                    final label = count > 99 ? '99+' : '$count';
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text(label, style: const TextStyle(fontSize: 10)),
                      child: const Icon(Icons.notifications_none_rounded, size: 22),
                    );
                  },
                  loading: () => const Icon(Icons.notifications_none_rounded, size: 22),
                  error: (_, __) => const Icon(Icons.notifications_none_rounded, size: 22),
                ),
              ),
              IconButton(
                tooltip: 'Cart',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => navigateToCartPage(ref, context),
                icon: cartQty > 0
                    ? Badge(
                        label: Text(
                          cartQty > 99 ? '99+' : '$cartQty',
                          style: const TextStyle(fontSize: 10),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined, size: 22),
                      )
                    : const Icon(Icons.shopping_cart_outlined, size: 22),
              ),
            ],
          ),
        );
      },
    );
  }
}
