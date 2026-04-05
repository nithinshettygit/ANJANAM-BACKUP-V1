import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/layout/storefront_web_layout.dart';
import '../../core/theme/app_colors.dart';
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

  /// Popular rail only — tighter than [railCardGap] to reduce empty space between cards.
  static double popularRailCardGap(BuildContext context) {
    if (!kIsWeb) return 8;
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 10;
    if (w >= StorefrontBreakpoints.mobile) return 9;
    return 8;
  }

  /// Festival banner rail — wider than [railCardGap] so narrower cards breathe horizontally.
  static double festivalRailCardGap(BuildContext context) {
    if (!kIsWeb) return 16;
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 24;
    if (w >= StorefrontBreakpoints.mobile) return 20;
    return 16;
  }

  /// Top inset for the home hero on web desktop.
  static double homeHeroTopMargin(BuildContext context) {
    if (_webDesktop(context)) return 18;
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
    if (w > StorefrontBreakpoints.tablet) return 24;
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
  ///
  /// Aligns with [homeCategoryRowTitleStyle] (“Shop by category”): [TextTheme.titleLarge]
  /// on phones and narrow web; +2px on wide web desktop only. On very small native
  /// screens the size steps down slightly so rails don’t feel oversized.
  static double homeSectionTitleFontSize(BuildContext context) {
    final baseFs = Theme.of(context).textTheme.titleLarge?.fontSize ?? 18;

    if (kIsWeb) {
      final w = StorefrontLayoutScope.layoutWidthOf(context);
      if (w > StorefrontBreakpoints.tablet) return baseFs + 2;
      return baseFs;
    }

    final sw = MediaQuery.sizeOf(context).width;
    if (sw < 320) return (baseFs - 3).clamp(14.0, baseFs);
    if (sw < 360) return (baseFs - 2).clamp(14.0, baseFs);
    if (sw < 400) return (baseFs - 1).clamp(15.0, baseFs);
    return baseFs;
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

  /// Recommended rail card title (product name).
  static TextStyle homeRecommendedRailTitleStyle(BuildContext context, TextTheme theme) {
    final base = theme.titleSmall ?? const TextStyle();
    final baseFs = base.fontSize ?? 14;
    if (!kIsWeb) {
      return base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.28,
        letterSpacing: -0.28,
        color: AppColors.sectionTitle,
      );
    }
    var style = base.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.22,
      letterSpacing: -0.25,
      color: AppColors.sectionTitle,
    );
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    final fs = style.fontSize ?? baseFs;
    if (w > StorefrontBreakpoints.tablet) {
      return style.copyWith(fontSize: fs + 2, height: 1.3);
    }
    if (w >= StorefrontBreakpoints.mobile) {
      return style.copyWith(fontSize: fs + 1, height: 1.28);
    }
    return style.copyWith(fontSize: baseFs + 0.5);
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

  static const double _homeCategoryNativeInterItemGap = 8;

  /// Horizontal inset on each Shop-by-category chip (both sides; counts toward stride).
  static const double homeCategoryChipPaddingH = 2;

  /// Column width past the icon diameter for the two-line label.
  static const double homeCategoryChipLabelSlotExtra = 12;

  /// Horizontal gap between category circles on the home scroller.
  static double homeCategoryScrollerGap(BuildContext context) {
    if (!kIsWeb) return _homeCategoryNativeInterItemGap;
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (w > StorefrontBreakpoints.tablet) return 14;
    if (w >= StorefrontBreakpoints.mobile) return 12;
    return 12;
  }

  static double heroHeight(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb && w > StorefrontBreakpoints.tablet) {
      return (w * 0.22).clamp(220.0, 320.0);
    }
    return (w * 0.38).clamp(160.0, 200.0);
  }

  /// Standard horizontal rail (Popular). Slightly larger than before so cards read closer to Recommended scale.
  static double popularCardWidth(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb) {
      if (w >= StorefrontBreakpoints.tablet) {
        return (w * 0.24).clamp(172.0, 204.0);
      }
      if (w >= StorefrontBreakpoints.mobile) {
        return (w * 0.345).clamp(162.0, 188.0);
      }
    }
    return (w * 0.43).clamp(160.0, 180.0);
  }

  /// Square image (1:1) + text block (card body height).
  static double popularCardBodyHeight(double cardWidth) => cardWidth + 96;

  /// List viewport height: card body + shelf list bottom inset (padding + web scrollbar band).
  static double popularRailHeight(BuildContext context, double cardWidth) =>
      popularCardBodyHeight(cardWidth) + homeShelfRailListBottomInset(context);

  /// Native Popular paged rail: peek in [homeRailSnapViewportFraction] **and** right inset on each page.
  ///
  /// Using the **same** value for both makes the visible gap between cards equal [popularRailCardGap]
  /// (same rhythm as Recommended’s [ListView] separators).
  static double popularRailSnapEndInset(double railGap) =>
      railGap.clamp(5.0, 10.0);

  /// Width available for rail content inside a home section shelf (after page + shelf insets).
  static double homeShelfContentWidth(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    final outer = pageHorizontal(context);
    final inner = homeSectionShelfInnerPadding(context);
    return (w - 2 * outer - 2 * inner).clamp(120.0, w);
  }

  /// [PageView.viewportFraction] so one card + gap fits per page on native (swipe-by-card).
  ///
  /// [nextCardPeekPx] widens each page slightly so the next product is hinted at the edge
  /// (Popular rail uses this for clearer horizontal affordance).
  static double homeRailSnapViewportFraction(
    BuildContext context,
    double cardWidth,
    double separatorWidth, {
    double nextCardPeekPx = 0,
  }) {
    final shelfW = homeShelfContentWidth(context);
    if (shelfW <= 0) return 0.88;
    final stride = cardWidth + separatorWidth + nextCardPeekPx;
    return (stride / shelfW).clamp(0.28, 0.95);
  }

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

  /// Meta strip under image: 2-line title + rating row + prices + CTA.
  static const double recommendedMetaStripMinHeight = 118;

  static double recommendedCardBodyHeight(double cardWidth) =>
      recommendedImageHeight(cardWidth) +
      recommendedMetaStripMinHeight +
      32; // insets + slack when rating row + 2-line title

  static double recommendedRailHeight(BuildContext context, double cardWidth) =>
      recommendedCardBodyHeight(cardWidth) + homeShelfRailListBottomInset(context);

  /// Wide festival promo cards.
  static double festivalCardWidth(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb) {
      if (w >= StorefrontBreakpoints.tablet) {
        return (w * 0.36).clamp(280.0, 420.0);
      }
      return (w * 0.55).clamp(220.0, 300.0);
    }
    return (w * 0.74).clamp(248.0, 292.0);
  }

  static double festivalCardHeight(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb && w >= StorefrontBreakpoints.tablet) {
      return (w * 0.205).clamp(228.0, 288.0);
    }
    if (kIsWeb) {
      return (w * 0.27).clamp(192.0, 228.0);
    }
    return (w * 0.28).clamp(196.0, 236.0);
  }

  /// Bottom space inside horizontal rails so the web scrollbar clears card art.
  static double horizontalRailScrollbarReserve(BuildContext context) {
    if (!kIsWeb) return 0;
    return 14;
  }

  /// Matches [WebHorizontalRailList] bottom inset on home shelves: `inner + 2` + scrollbar band.
  /// Without this, rail [height] is shorter than padded viewport and cards overflow vertically.
  static double homeShelfRailListBottomInset(BuildContext context) =>
      homeSectionShelfInnerPadding(context) +
      2 +
      horizontalRailScrollbarReserve(context);

  static double festivalRailHeight(BuildContext context) {
    final cardH = festivalCardHeight(context);
    return cardH + 4 + homeShelfRailListBottomInset(context);
  }

  /// Category circles (Shop by category).
  ///
  /// On native, size is chosen so **four** chips fit across the content width with
  /// [homeCategoryScrollerGap] and [homeCategoryChipPaddingH] / [homeCategoryChipLabelSlotExtra].
  static double categoryIconSize(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (kIsWeb && w > StorefrontBreakpoints.tablet) {
      return (w * 0.075).clamp(80.0, 96.0);
    }
    if (!kIsWeb) {
      final content = w - 2 * pageHorizontal(context);
      const overhead =
          2 * homeCategoryChipPaddingH + homeCategoryChipLabelSlotExtra;
      final raw = (content -
              3 * _homeCategoryNativeInterItemGap -
              4 * overhead) /
          4;
      return raw.clamp(52.0, 74.0);
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

  /// Inner horizontal padding inside the tinted home section “shelf” (Flipkart-style block).
  static double homeSectionShelfInnerPadding(BuildContext context) {
    if (kIsWeb &&
        StorefrontLayoutScope.layoutWidthOf(context) > StorefrontBreakpoints.tablet) {
      return 16;
    }
    return 12;
  }

  /// [newArrivalCardWidth] when the grid sits inside a shelf (outer page pad + shelf inner pad).
  static double newArrivalCardWidthInShelf(BuildContext context, int columns) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    final outer = pageHorizontal(context);
    final inner = homeSectionShelfInnerPadding(context);
    final gap = newArrivalsGridCrossGap(context);
    return (w - 2 * outer - 2 * inner - gap * (columns - 1)) / columns;
  }

  /// Shared horizontal inset for home sections (mobile unchanged on Android).
  static double pageHorizontal(BuildContext context) {
    final w = StorefrontLayoutScope.layoutWidthOf(context);
    if (!kIsWeb) return AppSpacing.page.toDouble();
    if (w > StorefrontBreakpoints.tablet) return 24;
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
