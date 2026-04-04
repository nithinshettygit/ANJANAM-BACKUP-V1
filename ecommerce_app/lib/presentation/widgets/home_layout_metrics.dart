import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/layout/storefront_web_layout.dart';
import '../../core/theme/app_spacing.dart';

/// Responsive sizes for mixed home layouts (Flipkart / Amazon–style).
abstract final class HomeLayoutMetrics {
  /// Web layout width strictly above tablet breakpoint (desktop home polish).
  static bool _webDesktop(BuildContext context) {
    return kIsWeb &&
        StorefrontLayoutScope.layoutWidthOf(context) > StorefrontBreakpoints.tablet;
  }

  /// Vertical space after major homepage sections (rails, grids, categories).
  static double homeSectionBottomSpacing(BuildContext context) {
    if (_webDesktop(context)) return 48;
    return AppSpacing.section.toDouble();
  }

  /// Space between section header row and product rail / grid.
  static double sectionHeaderToContentGap(BuildContext context) {
    if (!kIsWeb) return AppSpacing.cardGap.toDouble();
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 16;
    if (w >= StorefrontBreakpoints.mobile) return 14;
    return AppSpacing.cardGap.toDouble();
  }

  /// Horizontal gap between cards in product rails.
  static double railCardGap(BuildContext context) {
    if (!kIsWeb) return AppSpacing.cardGap.toDouble();
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 16;
    if (w >= StorefrontBreakpoints.mobile) return 14;
    return AppSpacing.cardGap.toDouble();
  }

  /// Top inset for the home hero on web desktop.
  static double homeHeroTopMargin(BuildContext context) {
    if (_webDesktop(context)) return 28;
    return 0;
  }

  /// Bottom inset below the hero (web desktop uses looser rhythm).
  static double homeHeroBottomMargin(BuildContext context) {
    if (_webDesktop(context)) return 36;
    return AppSpacing.section.toDouble();
  }

  /// [ListView] top / bottom padding for the home feed.
  static double homeListTopPadding(BuildContext context) {
    if (!kIsWeb) return AppSpacing.cardGap.toDouble();
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 40;
    if (w >= StorefrontBreakpoints.mobile) return 24;
    return AppSpacing.cardGap.toDouble();
  }

  static double homeListBottomPadding(BuildContext context) {
    if (!kIsWeb) return AppSpacing.section.toDouble();
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 56;
    if (w >= StorefrontBreakpoints.mobile) return 40;
    return AppSpacing.section.toDouble();
  }

  /// Section title size in [HomeStorefrontSectionHeader].
  static double homeSectionTitleFontSize(BuildContext context) {
    if (!kIsWeb) return 20;
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 24;
    if (w >= StorefrontBreakpoints.mobile) return 22;
    return 20;
  }

  static double homeSectionBadgeFontSize(BuildContext context) {
    if (_webDesktop(context)) return 13;
    return 12;
  }

  static double homeSectionViewAllFontSize(BuildContext context) {
    if (_webDesktop(context)) return 15;
    return 14;
  }

  /// Discovery / grid card product title (`HomeProductDiscoveryCard`).
  static double homeProductTitleFontSize(BuildContext context) {
    if (!kIsWeb) return 13;
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 15;
    if (w >= StorefrontBreakpoints.mobile) return 14;
    return 13;
  }

  static double homeProductTitleLineHeight(BuildContext context) {
    if (_webDesktop(context)) return 1.32;
    return 1.2;
  }

  /// Recommended rail card title line.
  static TextStyle homeRecommendedRailTitleStyle(BuildContext context, TextTheme theme) {
    final base = theme.titleSmall ?? const TextStyle();
    var style = base.copyWith(fontWeight: FontWeight.w700, height: 1.2);
    if (!kIsWeb) return style;
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    final fs = style.fontSize ?? 14;
    if (w > StorefrontBreakpoints.tablet) {
      return style.copyWith(fontSize: fs + 2, height: 1.3);
    }
    if (w >= StorefrontBreakpoints.mobile) {
      return style.copyWith(fontSize: fs + 1, height: 1.25);
    }
    return style;
  }

  /// Gap under “Shop by category” before the scroller.
  static double homeCategoryHeaderToScrollerGap(BuildContext context) {
    if (!kIsWeb) return AppSpacing.cardGap + 2;
    if (_webDesktop(context)) return 16;
    if (StorefrontLayoutScope.layoutWidthOf(context) >= StorefrontBreakpoints.mobile) {
      return 14;
    }
    return AppSpacing.cardGap + 2;
  }

  /// “Shop by category” heading on the home top row.
  static TextStyle? homeCategoryRowTitleStyle(BuildContext context, TextTheme theme) {
    final base = theme.titleLarge;
    if (base == null) return null;
    if (!_webDesktop(context)) {
      return base.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3);
    }
    final fs = (base.fontSize ?? 22) + 2;
    return base.copyWith(
      fontSize: fs,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.35,
      height: 1.25,
    );
  }

  /// Optional body copy for empty home sections (web desktop readability).
  static TextStyle? homeEmptySectionBodyStyle(BuildContext context, TextTheme theme) {
    final base = theme.bodyMedium;
    if (base == null) return null;
    if (!_webDesktop(context)) return base;
    final fs = (base.fontSize ?? 14) + 1;
    return base.copyWith(fontSize: fs, height: 1.45);
  }

  /// Horizontal gap between category circles on the home scroller.
  static double homeCategoryScrollerGap(BuildContext context) {
    if (!kIsWeb) return AppSpacing.page.toDouble();
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 20;
    if (w >= StorefrontBreakpoints.mobile) return 18;
    return AppSpacing.page.toDouble();
  }

  static double heroHeight(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb && w > StorefrontBreakpoints.tablet) {
      return (w * 0.22).clamp(220.0, 320.0);
    }
    return (w * 0.38).clamp(160.0, 200.0);
  }

  /// Standard horizontal rail (Popular).
  static double popularCardWidth(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb) {
      if (w >= StorefrontBreakpoints.tablet) {
        return (w * 0.22).clamp(168.0, 200.0);
      }
      if (w >= StorefrontBreakpoints.mobile) {
        return (w * 0.32).clamp(158.0, 182.0);
      }
    }
    return (w * 0.40).clamp(150.0, 170.0);
  }

  /// Square image (1:1) + text block (card body height).
  static double popularCardBodyHeight(double cardWidth) => cardWidth + 96;

  /// List viewport height: card body + optional web scrollbar band below cards.
  static double popularRailHeight(BuildContext context, double cardWidth) =>
      popularCardBodyHeight(cardWidth) + horizontalRailScrollbarReserve(context);

  /// Larger personalized rail (Recommended).
  static double recommendedCardWidth(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb && w >= StorefrontBreakpoints.tablet) {
      return (w * 0.28).clamp(220.0, 280.0);
    }
    return (w * 0.54).clamp(200.0, 220.0);
  }

  /// **4:5** image area height = [cardWidth] * 5/4 + meta (title, price, CTA).
  static double recommendedImageHeight(double cardWidth) => cardWidth * 5 / 4;

  static double recommendedCardBodyHeight(double cardWidth) =>
      recommendedImageHeight(cardWidth) + 136;

  static double recommendedRailHeight(BuildContext context, double cardWidth) =>
      recommendedCardBodyHeight(cardWidth) + horizontalRailScrollbarReserve(context);

  /// Wide festival promo cards.
  static double festivalCardWidth(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb) {
      if (w >= StorefrontBreakpoints.tablet) {
        return (w * 0.40).clamp(300.0, 440.0);
      }
      return (w * 0.62).clamp(240.0, 320.0);
    }
    return (w * 0.82).clamp(260.0, 300.0);
  }

  static double festivalCardHeight(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb && w >= StorefrontBreakpoints.tablet) {
      return (w * 0.16).clamp(180.0, 220.0);
    }
    return (w * 0.24).clamp(160.0, 180.0);
  }

  /// Bottom space inside horizontal rails so the web scrollbar clears card art.
  static double horizontalRailScrollbarReserve(BuildContext context) {
    if (!kIsWeb) return 0;
    return 14;
  }

  static double festivalRailHeight(BuildContext context) {
    final cardH = festivalCardHeight(context);
    return cardH + 4 + horizontalRailScrollbarReserve(context);
  }

  /// Category circles (Shop by category).
  static double categoryIconSize(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb && w > StorefrontBreakpoints.tablet) {
      return (w * 0.075).clamp(80.0, 96.0);
    }
    return (w * 0.19).clamp(72.0, 80.0);
  }

  static int newArrivalsColumnCount(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (!kIsWeb) {
      return w >= 420 ? 3 : 2;
    }
    if (w < StorefrontBreakpoints.mobile) return 2;
    if (w < StorefrontBreakpoints.tablet) return 3;
    if (w >= 1400) return 6;
    if (w >= 1200) return 5;
    return 4;
  }

  static const double newArrivalRowExtent = 240;
  static const int newArrivalsMaxPreview = 12;

  static double newArrivalsGridHeight({
    required int itemCount,
    required int crossAxisCount,
    double rowExtent = newArrivalRowExtent,
    double mainAxisSpacing = 12,
  }) {
    if (itemCount <= 0) return 0;
    final rows = (itemCount + crossAxisCount - 1) ~/ crossAxisCount;
    return rows * rowExtent + (rows - 1) * mainAxisSpacing;
  }

  static double newArrivalCardWidth(BuildContext context, int columns) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    final pad = pageHorizontal(context);
    final gap = newArrivalsGridCrossGap(context);
    return (w - pad * 2 - gap * (columns - 1)) / columns;
  }

  static double newArrivalsGridCrossGap(BuildContext context) {
    if (!kIsWeb) return AppSpacing.cardGap.toDouble();
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 20;
    if (w >= StorefrontBreakpoints.mobile) return 16;
    return AppSpacing.cardGap.toDouble();
  }

  /// Aligns new-arrivals grid with section rails (same horizontal inset).
  static double newArrivalsGridHorizontalPadding(BuildContext context) =>
      pageHorizontal(context);

  /// Shared horizontal inset for home sections (mobile unchanged on Android).
  static double pageHorizontal(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (!kIsWeb) return AppSpacing.page.toDouble();
    if (w > StorefrontBreakpoints.tablet) return 28;
    if (w >= StorefrontBreakpoints.mobile) return 24;
    return AppSpacing.page.toDouble();
  }

  /// Taller rows on web desktop for new arrivals grid breathing room.
  static double newArrivalRowExtentFor(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb && w > StorefrontBreakpoints.tablet) {
      return 260;
    }
    return newArrivalRowExtent;
  }
}
